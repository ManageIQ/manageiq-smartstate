require 'manageiq/gems/pending'
require 'openssl' # Required for 'Digest' in camcorder (< Ruby 2.1)
require 'camcorder'
require 'MiqVm/MiqVm'

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

#
# Path to RAW disk image.
#
VIRTUAL_DISK_FILE = "path to raw disk image file"

commit = true

begin
  recorder = Camcorder::Recorder.new("#{File.dirname(__FILE__)}/foo.yml")
  Camcorder.default_recorder = recorder
  Camcorder.intercept_constructor(MiqLargeFile::MiqLargeFileOther) do
    methods_with_side_effects :seek, :read, :write
  end
  Camcorder.intercept_constructor(MiqLargeFile::MiqLargeFileStat)

  recorder.start

  hardware  = "scsi0:0.present = \"TRUE\"\n"
  hardware += "scsi0:0.filename = \"#{VIRTUAL_DISK_FILE}\"\n"

  ost = OpenStruct.new
  ost.rawDisk = true

  miqVm = MiqVm.new(hardware, ost)

  %w(accounts services software system).each do |cat|
    xml = miqVm.extract(cat)
    xml.write($stdout, 4)
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
  commit = false # don't commit recording on error
ensure
  miqVm.unmount if miqVm
  puts "...done"
  if recorder && commit
    puts
    puts "camcorder: committing recording..."
    recorder.commit
    puts "done."
  end
end
