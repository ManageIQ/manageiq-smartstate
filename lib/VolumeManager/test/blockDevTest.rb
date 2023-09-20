require 'manageiq/gems/pending'
require 'ostruct'

require 'disk/MiqDisk'
require 'VolumeManager/MiqVolumeManager'

require 'logger'
$vim_log = $log = Logger.new(STDERR)
$log.level = Logger::DEBUG

begin

  volMgr = MiqVolumeManager.fromNativePvs

  puts
  puts "Volume Groups:"
  volMgr.vgHash.each do |vgName, vgObj|
    puts "\t#{vgName}: seq# = #{vgObj.seqNo}"
  end

  puts
  puts "Logical Volumes:"
  volMgr.lvHash.each do |key, lv|
    puts "\t#{key}\t#{lv.dInfo.lvObj.lvName}"
  end

  volMgr.closeAll

rescue  => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
