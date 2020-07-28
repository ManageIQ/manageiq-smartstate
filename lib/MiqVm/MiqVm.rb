require 'ostruct'
require 'metadata/VmConfig/VmConfig'
require 'disk/MiqDisk'
require 'VolumeManager/MiqVolumeManager'
require 'fs/MiqMountManager'
require 'metadata/MIQExtract/MIQExtract'

class MiqVm
  attr_reader :vmConfig, :vmConfigFile, :vim, :vimVm, :rhevm, :rhevmVm, :diskInitErrors, :wholeDisks

  def initialize(vmCfg, ost = nil)
    @ost = ost || OpenStruct.new
    $log.debug "MiqVm::initialize: @ost = nil" if $log && !@ost
    @vmDisks = nil
    @wholeDisks = []
    @rootTrees = nil
    @volumeManager = nil
    @applianceVolumeManager = nil
    @vmConfigFile = ""
    @diskInitErrors = {}
    unless vmCfg.kind_of?(Hash)
      @vmConfigFile = vmCfg
      @vmDir = File.dirname(vmCfg)
    end

    $log.debug "MiqVm::initialize: @ost.openParent = #{@ost.openParent}" if $log

    #
    # If we're passed an MiqVim object, then use VIM to obtain the Vm's
    # configuration through the instantiated server.
    # If we're passed a snapshot ID, then obtain the configration of the
    # VM when the snapshot was taken.
    #
    # TODO: move to MiqVmwareVm
    if (@vim = @ost.miqVim)
      $log.debug "MiqVm::initialize: accessing VM through server: #{@vim.server}" if $log.debug?
      @vimVm = @vim.getVimVm(vmCfg)
      $log.debug "MiqVm::initialize: setting @ost.miqVimVm = #{@vimVm.class}" if $log.debug?
      @ost.miqVimVm = @vimVm
      @vmConfig = VmConfig.new(@vimVm.getCfg(@ost.snapId))
    # TODO: move this to MiqRhevmVm.
    elsif (@rhevm = @ost.miqRhevm)
      $log.debug "MiqVm::initialize: accessing VM through RHEVM server" if $log.debug?
      $log.debug "MiqVm::initialize: vmCfg = #{vmCfg}"
      @rhevmVm = @rhevm.vm_or_template_by_path(vmCfg)
      $log.debug "MiqVm::initialize: setting @ost.miqRhevmVm = #{@rhevmVm.class}" if $log.debug?
      @ost.miqRhevmVm = @rhevmVm
      @vmConfig = VmConfig.new(getCfg(@ost.snapId))
      $log.debug "MiqVm::initialize: @vmConfig.getHash = #{@vmConfig.getHash.inspect}"
      $log.debug "MiqVm::initialize: @vmConfig.getDiskFileHash = #{@vmConfig.getDiskFileHash.inspect}"
    # TODO: move this to miq_scvmm_vm
    elsif (@scvmm = @ost.miq_scvmm)
      $log.debug "MiqVm::initialize: accessing VM through HyperV server" if $log.debug?
      @vmConfig = VmConfig.new(getCfg(@ost.snapId))
      $log.debug "MiqVm::initialize: setting @ost.miq_scvmm_vm = #{@scvmm_vm.class}" if $log.debug?
    else
      @vimVm = nil
      @vmConfig = VmConfig.new(vmCfg)
    end
  end # def initialize

  def vmDisks
    @vmDisks ||= begin
      @volMgrPS = VolMgrPlatformSupport.new(@vmConfig.configFile, @ost)
      @volMgrPS.preMount

      openDisks(@vmConfig.getDiskFileHash)
    end
  end

  def openDisks(diskFiles)
    pVolumes = []

    $log.debug "openDisks: no disk files supplied." unless diskFiles

    #
    # Build a list of the VM's physical volumes.
    #
    diskFiles.each do |dtag, df|
      $log.debug "openDisks: processing disk file (#{dtag}): #{df}"
      dInfo = OpenStruct.new

      if @ost.miqVim
        dInfo.vixDiskInfo            = {}
        dInfo.vixDiskInfo[:fileName] = @ost.miqVim.datastorePath(df)
        if @ost.miqVimVm
          @vdlConnection = @ost.miqVimVm.vdlVcConnection unless @vdlConnection
        else
          @vdlConnection = @ost.miqVim.vdlConnection unless @vdlConnection
        end
        $log.debug "openDisks: using disk file path: #{dInfo.vixDiskInfo[:fileName]}"
        dInfo.vixDiskInfo[:connection]  = @vdlConnection
      elsif @ost.miq_hyperv
        init_disk_info(dInfo, df)
      else
        dInfo.fileName = df
        disk_format = @vmConfig.getHash["#{dtag}.format"]  # Set by rhevm for iscsi and fcp disks
        dInfo.format = disk_format unless disk_format.blank?
      end

      mode = @vmConfig.getHash["#{dtag}.mode"]

      dInfo.hardwareId = dtag
      dInfo.baseOnly = @ost.openParent unless mode && mode["independent"]
      dInfo.rawDisk = @ost.rawDisk
      $log.debug "MiqVm::openDisks: dInfo.baseOnly = #{dInfo.baseOnly}"

      begin
        d = applianceVolumeManager && applianceVolumeManager.lvHash[dInfo.fileName] if @rhevm
        if d
          $log.debug "MiqVm::openDisks: using applianceVolumeManager for #{dInfo.fileName}" if $log.debug?
          d.dInfo.fileName = dInfo.fileName
          d.dInfo.hardwareId = dInfo.hardwareId
          d.dInfo.baseOnly = dInfo.baseOnly
          d.dInfo.format = dInfo.format if dInfo.format
          d.dInfo.applianceVolumeManager = applianceVolumeManager
          #
          # Here, we need to probe the disk to determine its data format,
          # QCOW for example. If the disk format is not flat, push a disk
          # supporting the format on top of this disk. Then set d to point
          # to the new top disk.
          #
          d = d.pushFormatSupport
        else
          d = MiqDisk.getDisk(dInfo)
          # I am not sure if getting a nil handle back should throw an error or not.
          # For now I am just skipping to the next disk.  (GMM)
          next if d.nil?
        end
      rescue => err
        $log.error "Couldn't open disk file: #{df}"
        $log.error err.to_s
        $log.debug err.backtrace.join("\n")
        @diskInitErrors[df] = err.to_s
        next
      end

      @wholeDisks << d
      p = d.getPartitions
      if p.empty?
        #
        # If the disk has no partitions, the whole disk can be a single volume.
        #
        pVolumes << d
      else
        #
        # If the disk is partitioned, the partitions are physical volumes,
        # but not the whild disk.
        #
        pVolumes.concat(p)
      end
    end

    pVolumes
  end # def openDisks

  def rootTrees
    return @rootTrees if @rootTrees
    @rootTrees = MiqMountManager.mountVolumes(volumeManager, @vmConfig, @ost)
    volumeManager.rootTrees = @rootTrees
    @rootTrees
  end

  def volumeManager
    @volumeManager ||= MiqVolumeManager.new(vmDisks)
  end

  def applianceVolumeManager
    return nil if @ost.nfs_storage_mounted
    @applianceVolumeManager ||= MiqVolumeManager.fromNativePvs
  end

  def snapshots(refresh = false)
    return nil unless @vimVm
    return @vimVm.snapshotInfo(refresh) if @vimVm
  end

  def unmount
    $log.info "MiqVm.unmount called."
    @wholeDisks.each(&:close)
    @wholeDisks.clear
    if @volumeManager
      @volumeManager.close
      @volumeManager = nil
    end
    @applianceVolumeManager.closeAll if @applianceVolumeManager
    @applianceVolumeManager = nil
    @ost.miqVim.closeVdlConnection(@vdlConnection) if @vdlConnection
    if @volMgrPS
      @volMgrPS.postMount
      @volMgrPS = nil
    end
    @vimVm.release if @vimVm
    @rootTrees = nil
    @vmDisks = nil
  end

  def miq_extract
    @miq_extract ||= MIQExtract.new(self, @ost)
  end

  def extract(c)
    xml = miq_extract.extract(c)
    raise "Could not extract \"#{c}\" from VM" unless xml
    (xml)
  end
end # class MiqVm
