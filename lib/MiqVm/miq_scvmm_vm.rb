require 'MiqVm/MiqVm'
require 'Scvmm/miq_scvmm_vm_ssa_info'

class MiqScvmmVm < MiqVm
  def getCfg(_snap = nil)
    cfg_hash = {}
    # Collect disk information
    vhds = @scvmm.vm_all_harddisks(@ost.miq_vm)
    raise "Unable to get Hard Disk Info from VM #{@ost.miq_vm}." unless vhds.any?
    vhds.each do |vhd_attributes|
      vhd      = vhd_attributes["Path"]
      type     = vhd_attributes["ControllerType"].downcase
      number   = vhd_attributes["ControllerNumber"]
      index = vhd_attributes["ControllerLocation"]
      tag = "#{type}#{number}:#{index}"
      cfg_hash["#{tag}.present"]    = "true"
      cfg_hash["#{tag}.devicetype"] = "disk"
      cfg_hash["#{tag}.filename"]   = vhd
    end
    cfg_hash
  end

  def get_vmconfig(_vm_config)
    @scvmm = @ost.miq_scvmm
    $log.debug "MiqVm::initialize: accessing VM through HyperV server" if $log.debug?
    #
    # If we're passed a snapshot ID, then obtain the configuration of the
    # VM when the snapshot was taken.
    #
    @vmConfig = VmConfig.new(getCfg(@ost.snapId))
    $log.debug "MiqVm::initialize: setting @ost.miq_scvmm_vm = #{@scvmm_vm.class}" if $log.debug?
  end

  private

  def init_disk_info(disk_info, disk_tag, disk_file)
    disk_info.hyperv_connection        = {}
    disk_info.fileName                 = disk_file
    disk_info.driveType                = @scvmm.get_drivetype(disk_file)
    disk_info.scvmm                    = @scvmm
    disk_info.hyperv_connection[:host] = @ost.miq_hyperv[:host]
    disk_info.hyperv_connection[:port] = @ost.miq_hyperv[:port]
    if @ost.miq_hyperv[:domain].nil?
      disk_info.hyperv_connection[:user] = @ost.miq_hyperv[:user]
    else
      disk_info.hyperv_connection[:user] = @ost.miq_hyperv[:domain] + "\\" + @ost.miq_hyperv[:user]
    end
    disk_info.hyperv_connection[:password] = @ost.miq_hyperv[:password]
    common_disk_info(disk_info, disk_tag)
  end
end
