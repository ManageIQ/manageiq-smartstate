require 'ostruct'
require 'MiqVm/MiqVm'
require 'fs/MiqFS/MiqFS'
require 'fs/MiqFS/modules/RealFS'

class MiqLocalVm < MiqVm
  def initialize
    @ost = OpenStruct.new
    @rootTrees = [MiqFS.new(RealFS, OpenStruct.new)]
    @volumeManager = OpenStruct.new
    @vmConfigFile = "Local VM"
    @vmDir = ""
    @vmConfig = OpenStruct.new
  end # def initialize

  attr_reader :rootTrees

  attr_reader :volumeManager

  def unmount
    $log.info "MiqLocalVm.unmount called."
  end
end # class MiqVm

if __FILE__ == $0
  require 'logger'
  $log = Logger.new(STDERR)
  $log.level = Logger::DEBUG

  vm = MiqLocalVm.new

  ["accounts", "services", "software", "system"].each do |cat|
    xml = vm.extract(cat)
    xml.write($stdout, 4)
  end

  vm.unmount
  puts "...done"
end
