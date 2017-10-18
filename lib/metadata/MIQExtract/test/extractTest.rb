require 'metadata/MIQExtract/MIQExtract'
require 'MiqVm/MiqVm'

# vmDir = "v:"
vmDir = File.join(ENV.fetch("HOME", '.'), 'VMs')
puts "vmDir = #{vmDir}"

require 'logger'
$log = Logger.new(STDERR)
$log.level = Logger::ERROR

#
# *** Test start
#

# vmCfgFile = File.join(vmDir, "UbuntuDev.vmwarevm/UbuntuDev.vmx")
# vmCfgFile = File.join(vmDir, "gentoo/gentoo.vmx")
# vmCfgFile = File.join(vmDir, "Ken_Linux/Ken_Linux.vmx")
# vmCfgFile = File.join(vmDir, "Metasploit VM/Metasploit VM.vmx")
# vmCfgFile = File.join(vmDir, "KnopDev.vmwarevm/KnopDev.vmx")
vmCfgFile = File.join(vmDir, "Red Hat Linux.vmwarevm/Red Hat Linux.vmx")
# vmCfgFile = File.join(vmDir, "MIQ Server Appliance - Ubuntu MD - small/MIQ Server Appliance - Ubuntu.vmx")
# vmCfgFile = File.join(vmDir, "winxpDev.vmwarevm/winxpDev.vmx")
puts "VM config file: #{vmCfgFile}"

ost = OpenStruct.new
vmCfg = MIQExtract.new(vmCfgFile, ost)
xml = vmCfg.extract(["software"])

xml.write($stdout, 4)
puts

vmCfg.close
