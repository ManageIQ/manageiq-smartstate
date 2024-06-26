#
# This test assumes the NFS share of the storage in question is mounted on the appliance.
#

require 'manageiq/gems/pending'
require 'ostruct'
require 'MiqVm/MiqVm'

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

DDIR = "/mnt/vm/7fd0b9b2-e362-11e2-97b7-001a4aa8fcea/rhev/data-center/773f2ddf-7765-42fc-85d6-673b718541cd/aa7e70e5-40d0-43e2-a605-92ce6ba652a8/images/19449cf8-1905-4b8a-b45a-e845a693a3df"
BASE_FILE = "#{DDIR}/903306be-f676-4005-a813-daa6d7a6c33f"
REDO_FILE = "#{DDIR}/9e7075c5-a014-4ddf-a168-a33723d0c3cd"

# DISK_FILE = BASE_FILE
DISK_FILE = REDO_FILE

diskid    = "scsi0:0"
hardware  = "#{diskid}.present = \"TRUE\"\n"
hardware += "#{diskid}.filename = \"#{DISK_FILE}\"\n"

begin
  puts
  puts `file #{DISK_FILE}`
  puts

  ost = OpenStruct.new
  ost.fileName = DISK_FILE

  vm = MiqVm.new(hardware, ost)

  raise "No filesystems detected." if vm.rootTrees.empty?

  puts "\nChecking for file systems..."
  vm.rootTrees.each do |fs|
    puts "*** Found root tree for #{fs.guestOS}"
    puts "Listing files in #{fs.pwd} directory:"
    fs.dirEntries.each { |de| puts "\t#{de}" }
    puts
  end

  ["services", "software", "system", "vmconfig"].each do |c|
    puts
    puts "Extracting #{c}"
    vm.extract(c) # .to_xml.write($stdout, 4)
  end
rescue => err
  $log.error err.to_s
  $log.error err.backtrace.join("\n")
ensure
  # vm.unmount if vm
end
