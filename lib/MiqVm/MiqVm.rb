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

    get_vmconfig(vmCfg)
  end

  def get_vmconfig(vm_config)
    #
    # If we're passed an MiqVim object, then use VIM to obtain the Vm's
    # configuration through the instantiated server.
    #
    if (@vim = @ost.miqVim)
      $log.debug "MiqVm::initialize: accessing VM through server: #{@vim.server}" if $log.debug?
      @vimVm = @vim.getVimVm(vm_config)
      $log.debug "MiqVm::initialize: setting @ost.miqVimVm = #{@vimVm.class}" if $log.debug?
      @ost.miqVimVm = @vimVm
      @vmConfig = VmConfig.new(@vimVm.getCfg(@ost.snapId))
    else
      @vimVm = nil
      @vmConfig = VmConfig.new(vm_config)
    end
  end

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
      init_disk_info(dInfo, dtag, df)

      begin
        d = init_disk(dInfo)
        # I am not sure if getting a nil handle back should throw an error or not.
        # For now I am just skipping to the next disk.  (GMM)
        next if d.nil?
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

  def init_disk_info(d_info, disk_tag, disk_file)
    if @ost.miqVim
      vim_disk_info(d_info, disk_file)
    else
      d_info.fileName = disk_file
      disk_format     = @vmConfig.getHash["#{disk_tag}.format"]  # Set by rhevm for iscsi and fcp disks
      d_info.format   = disk_format if disk_format.present?
    end
    common_disk_info(d_info, disk_tag)
  end

  def vim_disk_info(d_info, disk_file)
    d_info.vixDiskInfo            = {}
    d_info.vixDiskInfo[:fileName] = @ost.miqVim.datastorePath(disk_file)
    @vdlConnection ||=
      if @ost.miqVimVm
        @ost.miqVimVm.vdlVcConnection
      else
        @ost.miqVim.vdlConnection
      end
    $log.debug("init_disk_info: using disk file path: #{d_info.vixDiskInfo[:fileName]}")
    d_info.vixDiskInfo[:connection] = @vdlConnection
  end

  def common_disk_info(d_info, disk_tag)
    mode              = @vmConfig.getHash["#{disk_tag}.mode"]
    d_info.hardwareId = disk_tag
    d_info.baseOnly   = @ost.openParent unless mode && mode["independent"]
    d_info.rawDisk    = @ost.rawDisk
    $log.debug("MiqVm::init_disk_info: d_info.baseOnly = #{d_info.baseOnly}")
  end

  def init_disk(d_info)
    MiqDisk.getDisk(d_info)
  end

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

if __FILE__ == $0
  require 'metadata/util/win32/boot_info_win'

  # vmDir = File.join(ENV.fetch("HOME", '.'), 'VMs')
  vmDir = "/volumes/WDpassport/Virtual Machines"
  puts "vmDir = #{vmDir}"

  targetLv = "rpolv2"
  rootLv = "LogVol00"

  require 'logger'
  $log = Logger.new(STDERR)
  $log.level = Logger::DEBUG

  #
  # *** Test start
  #

  # vmCfg = File.join(vmDir, "cacheguard/cacheguard.vmx")
  # vmCfg = File.join(vmDir, "Red Hat Linux.vmwarevm/Red Hat Linux.vmx")
  # vmCfg = File.join(vmDir, "MIQ Server Appliance - Ubuntu MD - small/MIQ Server Appliance - Ubuntu.vmx")
  # vmCfg = File.join(vmDir, "winxpDev.vmwarevm/winxpDev.vmx")
  vmCfg = File.join(vmDir, "Win2K_persistent/Windows 2000 Professional.vmx")
  # vmCfg = File.join(vmDir, "Win2K_non_persistent/Windows 2000 Professional.vmx")
  puts "VM config file: #{vmCfg}"

  ost = OpenStruct.new
  ost.openParent = true

  vm = MiqVm.new(vmCfg, ost)

  puts "\n*** Disk Files:"
  vm.vmConfig.getDiskFileHash.each do |k, v|
    puts "\t#{k}\t#{v}"
  end

  puts "\n*** configHash:"
  vm.vmConfig.getHash.each do |k, v|
    puts "\t#{k} => #{v}"
  end

  tlv = nil
  rlv = nil
  puts "\n*** Visible Volumes:"
  vm.volumeManager.visibleVolumes.each do |vv|
    puts "\tDisk type: #{vv.diskType}"
    puts "\tDisk sig: #{vv.diskSig}"
    puts "\tStart LBA: #{vv.lbaStart}"
    if vv.respond_to?(:logicalVolume)
      puts "\t\tLV name: #{vv.logicalVolume.lvName}"
      puts "\t\tLV UUID: #{vv.logicalVolume.lvId}"
      tlv = vv if vv.logicalVolume.lvName == targetLv
      rlv = vv if vv.logicalVolume.lvName == rootLv
    end
  end

  # raise "#{targetLv} not found" if !tlv
  #
  # tlv.seek(0, IO::SEEK_SET)
  # rs = tlv.read(2040)
  # puts "\n***** START *****"
  # puts rs
  # puts "****** END ******"
  #
  # tlv.seek(2048*512*5119, IO::SEEK_SET)
  # rs = tlv.read(2040)
  # puts "\n***** START *****"
  # puts rs
  # puts "****** END ******"
  #
  # raise "#{rootLv} not found" if !rlv
  #
  # puts "\n*** Mounting #{rootLv}"
  # rfs = MiqFS.getFS(rlv)
  # puts "\tFS Type: #{rfs.fsType}"
  # puts "\t*** Root-level files and directories:"
  # rfs.dirForeach("/") { |de| puts "\t\t#{de}" }

  puts "\n***** Detected Guest OSs:"
  raise "No OSs detected" if vm.rootTrees.length == 0
  vm.rootTrees.each do |rt|
    puts "\t#{rt.guestOS}"
    if rt.guestOS == "Linux"
      puts "\n\t\t*** /etc/fstab contents:"
      rt.fileOpen("/etc/fstab", &:read).each_line do |fstl|
        next if fstl =~ /^#.*$/
        puts "\t\t\t#{fstl}"
      end
    end
  end

  vm.rootTrees.each do |rt|
    if rt.guestOS == "Linux"
      # tdirArr = [ "/", "/boot", "/var/www/miq", "/var/www/miq/vmdb/log", "/var/lib/mysql" ]
      tdirArr = ["/", "/boot", "/etc/init.d", "/etc/rc.d/init.d", "/etc/rc.d/rc0.d"]

      tdirArr.each do |tdir|
        begin
          puts "\n*** Listing #{tdir} directory (1):"
          rt.dirForeach(tdir) { |de| puts "\t\t#{de}" }
          puts "*** end"

          puts "\n*** Listing #{tdir} directory (2):"
          rt.chdir(tdir)
          rt.dirForeach { |de| puts "\t\t#{de}" }
          puts "*** end"
        rescue => err
          puts "*** #{err}"
        end
      end

      # lf = rt.fileOpen("/etc/rc0.d/S01halt")
      # puts "\n*** Contents of /etc/rc0.d/S01halt:"
      # puts lf.read
      # puts "*** END"
      # lf.close
      #
      # lfn = "/etc/rc0.d/S01halt"
      # puts "Is #{lfn} a symbolic link? #{rt.fileSymLink?(lfn)}"
      # puts "#{lfn} => #{rt.getLinkPath(lfn)}"
    else  # Windows
      tdirArr = ["c:/", "e:/", "e:/testE2", "f:/"]

      tdirArr.each do |tdir|
        puts "\n*** Listing #{tdir} directory (1):"
        rt.dirForeach(tdir) { |de| puts "\t\t#{de}" }
        puts "*** end"

        puts "\n*** Listing #{tdir} directory (2):"
        rt.chdir(tdir)
        rt.dirForeach { |de| puts "\t\t#{de}" }
        puts "*** end"
      end
    end
  end

  vm.unmount
  puts "...done"
end
