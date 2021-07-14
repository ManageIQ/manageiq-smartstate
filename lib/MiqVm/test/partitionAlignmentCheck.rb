require 'manageiq-gems-pending'
require 'ostruct'
require 'MiqVm/MiqVm'
require 'VmwareWebService/MiqVim'

require 'logger'
$vim_log = $log = Logger.new(STDERR)

SERVER        = raise "please define SERVER"
USERNAME      = raise "please define USERNAME"
PASSWORD      = raise "please define PASSWORD"
vim = MiqVim.new(:server => SERVER, :username => USERNAME, :password => PASSWORD)

vimVm = nil
vm    = nil

alignment = 64 * 1024 # Check for alignment on a 64kB boundary

begin

  vim.virtualMachinesByMor.values.each do |vmo|
    begin
      vimVm = vim.getVimVmByMor(vmo['MOR'])

      vmx = vimVm.dsPath
      puts "VM: #{vimVm.name}, VMX = #{vmx}"

      if vimVm.poweredOn?
        puts "\tSkipping running VM"
        puts
        next
      end

      ost = OpenStruct.new
      ost.miqVim = vim

      #
      # Given an MiqVm object, we check to see if its partitions are aligned on a given boundary.
      # This boundary is usually based on the logical block size of the underlying storage array;
      # in this example, 64kB.
      #
      vm = MiqVm.new(vmx, ost)

      #
      # We check all of physical volumes of the VM. This Includes visible and hidden volumes, but excludes logical volumes.
      # The alignment of hidden volumes affects the performance of the logical volumes that are based on them.
      #
      vm.volumeManager.allPhysicalVolumes.each do |pv|
        vmdk = pv.dInfo.filename || pv.dInfo.vixDiskInfo[:fileName]
        aligned = pv.startByteAddr % alignment == 0 ? "Yes" : "No"
        puts "\t#{vmdk}, Partition: #{pv.partNum}, Partition type: #{pv.partType}, LBA: #{pv.lbaStart}, offset: #{pv.startByteAddr}, aligned: #{aligned}"
      end

      puts
    ensure
      vimVm.release if vimVm
      vm.unmount    if vm
      vimVm = vm = nil
    end
  end

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect  if vim
end
