require 'manageiq-gems-pending'
require 'ostruct'
require 'MiqVm/MiqVm'
require 'VMwareWebService/MiqVim'

require 'logger'
$vim_log = $log = Logger.new(STDERR)

SERVER        = raise "please define SERVER"
PORT          = 443
DOMAIN        = raise "please define DOMAIN"
USERNAME      = raise "please define USERNAME"
PASSWORD      = raise "please define PASSWORD"
TARGET_VM     = raise "please define TARGET_VM"

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  vim_vm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  unless vim_vm
    puts "VM: #{TARGET_VM} not found"
    vim.disconnect
    exit
  end

  vmx = vim_vm.dsPath.to_s
  puts "Found target VM: #{TARGET_VM}, VMX = #{vmx}"

  ost = OpenStruct.new
  ost.miqVim = vim

  vm = MiqVm.new(vmx, ost)

  vm.rootTrees.each do |fs|
    puts "*** Found root tree for #{fs.guestOS}"
    puts "Listing files in #{fs.pwd} directory:"
    fs.dirEntries.each { |de| puts "\t#{de}" }
    puts
  end

  CATEGORIES  = %w(accounts services software system)
  CATEGORIES.each do |cat|
    puts "Extracting: #{cat}:"
    xml = vm.extract(cat)
    xml.write($stdout, 4)
    puts
  end

  vm.unmount

  vim.disconnect
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
