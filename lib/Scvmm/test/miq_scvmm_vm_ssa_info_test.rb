require 'manageiq-gems-pending'
require 'rubygems'
require 'Scvmm/miq_scvmm_vm_ssa_info'

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

HOST = raise "Please define SERVERNAME"
PORT = raise "Please define PORT"
USER = raise "Please define USER"
PASS = raise "Please define PASS"
VM   = raise "Please define VM"

vm_info_handle = MiqScvmmVmSSAInfo.new(HOST, USER, PASS, PORT)
$log.debug "Getting Hyper-V Host for VM #{VM}"
hyperv_host = vm_info_handle.vm_host(VM)
$log.debug "Hyper-V Host is #{hyperv_host}"
$log.debug "Getting VHD Type for VM #{VM}"
vhd_type = vm_info_handle.vm_vhdtype(VM)
$log.debug "VHD Type is #{vhd_type}"
vhd = vm_info_handle.vm_harddisks(VM)
$log.debug "VHD is #{vhd}"
vm_info_handle.vm_create_checkpoint(VM)
checkpoint = vm_info_handle.vm_get_checkpoint(VM)
$log.debug "Checkpoint for #{vhd} is #{checkpoint}"
vm_info_handle.vm_remove_checkpoint(VM)
vm_info_handle.vm_create_checkpoint(VM)
checkpoint = vm_info_handle.vm_get_checkpoint(VM)
$log.debug "Checkpoint for #{vhd} is #{checkpoint}"
vm_info_handle.vm_remove_checkpoint(VM)
