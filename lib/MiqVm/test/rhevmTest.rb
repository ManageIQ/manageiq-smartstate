require 'manageiq/gems/pending'
require 'ostruct'
require 'MiqVm/MiqVm'
require 'ovirt'
require 'manageiq/providers/ovirt/legacy/inventory'
Ovirt.logger = $rhevm_log if $rhevm_log

RHEVM_SERVER        = raise "please define RHEVM_SERVER"
RHEVM_PORT          = 443
RHEVM_DOMAIN        = raise "please define RHEVM_DOMAIN"
RHEVM_USERNAME      = raise "please define RHEVM_USERNAME"
RHEVM_PASSWORD      = raise "please define RHEVM_PASSWORD"
VM_NAME             = raise "please define VM_NAME"

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

begin

  $rhevm = ManageIQ::Providers::Ovirt::Legacy::Inventory.new(
    :server     => RHEVM_SERVER,
    :port       => RHEVM_PORT,
    :domain     => RHEVM_DOMAIN,
    :username   => RHEVM_USERNAME,
    :password   => RHEVM_PASSWORD,
    :verify_ssl => false
  )

  puts "Attempting to scan VM: #{VM_NAME}"

  unless (rvm = Ovirt::Vm.find_by_name($rhevm.service, VM_NAME))
    raise "Could not find VM: #{VM_NAME}"
  end

  ost = OpenStruct.new
  ost.miqRhevm    = $rhevm
  ost.openParent  = false

  vm = MiqVm.new(rvm.api_endpoint, ost)

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

  vm.unmount
  puts "...done"

rescue => err
  $log.error err.to_s
  $log.error err.backtrace.join("\n")
end
