require 'ostruct'
require 'disk/MiqDisk'

VMDK  = "/Volumes/WDpassport/Virtual Machines/Red Hat Linux.vmwarevm/payload2.vmdk"
MKFILE  = "rawmkfs"

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

diskInfo = OpenStruct.new
diskInfo.mountMode = "rw"
diskInfo.fileName = VMDK

disk = MiqDisk.getDisk(diskInfo)

unless disk
  puts "Failed to open disk: #{diskInfo.fileName}"
  exit(1)
end

puts "Disk type: #{disk.diskType}"
puts "Disk partition type: #{disk.partType}"
puts "Disk block size: #{disk.blockSize}"
puts "Disk start LBA: #{disk.lbaStart}"
puts "Disk end LBA: #{disk.lbaEnd}"
puts "Disk start byte: #{disk.startByteAddr}"
puts "Disk end byte: #{disk.endByteAddr}"
puts

parts = disk.getPartitions

if parts && !parts.empty?
  puts "Disk is partitioned, exiting"
  exit(0)
end

diskSize = disk.endByteAddr - disk.startByteAddr
mkSize = File.size(MKFILE)
diskOffset = diskSize - mkSize

puts "Disk size:   #{diskSize}"
puts "Mk size:     #{mkSize}"
puts "Disk offset: #{diskOffset}"

mkf = File.open(MKFILE)

disk.seek(diskOffset)
while (buf = mkf.read(1024))
  disk.write(buf, buf.length)
end

mkf.close
disk.close
