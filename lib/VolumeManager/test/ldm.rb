require 'manageiq/gems/pending'
require 'ostruct'
require 'more_core_extensions/core_ext/object/blank'
require 'metadata/VmConfig/VmConfig'
require "VolumeManager/MiqVolumeManager"
require "fs/MiqFS/MiqFS"
require "MiqVm/MiqVim"
require "MiqVm/MiqVm"

SRC_VM = raise "please define"
vmCfg = "/Volumes/WDpassport/Virtual Machines/MIQAppliance-win2008x86/Win2008x86.vmx"

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

vm = nil
vim = nil

begin
  # Uncomment following 2 lines for clienr/server connection.
  # vim = MiqVim.new(:server => SERVER, :username => USERNAME, :password => PASSWORD)
  # miqVm = vim.getVimVmByFilter("config.name" => SRC_VM)
  #
  # vmCfg = miqVm.vmh['summary']['config']['vmPathName']
  puts "vmCfg: #{vmCfg}"

  $miqOut = $stdout
  ost = OpenStruct.new
  # ost.miqVim = vim
  vm = MiqVm.new(vmCfg, ost)

  # puts "**** Volume information:"
  # xml = vm.volumeManager.toXml
  # xml.write($stdout, 4)
  # puts

  rta = vm.rootTrees
  raise "No root filesystems detected for: #{vmCfg}" if rta.empty?
  rt = rta.first
  puts "**** Filesystem information:"
  rt.toXml
  puts

  # exit

  puts "**** First-level files:"
  puts "C:"
  rt.dirForeach("C:/") { |f| puts "\t#{f}" }
  # puts "F:"
  # rt.dirForeach("F:/") { |f| puts "\t#{f}" }

  puts
  puts "******************* SOFTWARE:"
  xml = vm.extract("software")
  xml.write($stdout, 4)
  puts

  exit

  vmConfig = VmConfig.new(vmCfg)
  volMgr = MiqVolumeManager.new(vmConfig)

  volMgr.visibleVolumes.each do |vv|
    puts "Disk type: #{vv.diskType}"
    puts "Disk partition type: #{vv.partType}"
    puts "Disk block size: #{vv.blockSize}"
    puts "Disk start LBA: #{vv.lbaStart}"
    puts "Disk end LBA: #{vv.lbaEnd}"
    puts "Disk start byte: #{vv.startByteAddr}"
    puts "Disk end byte: #{vv.endByteAddr}"
    if (lvObj = vv.dInfo.lvObj)
      puts "Drive Hint: #{lvObj.driveHint}"
    end

    if (fs = MiqFS.getFS(vv))
      puts "\tFS type: #{fs.fsType}"
      fs.dirForeach { |f| puts "\t\t#{f}" }
    else
      puts "\tNo FS detected on volume"
    end
    puts
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vm.unmount if vm
end
