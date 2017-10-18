require 'manageiq-gems-pending'
require 'rubygems'
require 'Scvmm/miq_hyperv_disk'

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

HOST = raise "Please define SERVERNAME"
PORT = raise "Please define PORT"
USER = raise "Please define USER"
PASS = raise "Please define PASS"
DISK = raise "Please define DISK"

hyperv_disk = MiqHyperVDisk.new(HOST, USER, PASS, PORT)

$log.debug "Reading 256 byte slices"
hyperv_disk.open(DISK)
hyperv_disk.seek(0)
(1..8).each do |i|
  buffer = hyperv_disk.read(256)
  $log.debug "Buffer #{i}: \n#{buffer}\n"
end
