require 'metadata/VmConfig/GetNativeCfg'
require 'VolumeManager/MiqNativeVolumeManager'
require 'fs/MiqMountManager'

module MiqNativeMountManager
  def self.mountVolumes
    cfg = GetNativeCfg.new
    volMgr = MiqNativeVolumeManager.new(cfg)

    (MiqMountManager.mountVolumes(volMgr, cfg))
  end
end # module MiqNativeMountManager

if __FILE__ == $0
  require 'logger'
  $log = Logger.new(STDERR)
  $log.level = Logger::DEBUG

  puts "Log debug?: #{$log.debug?}"

  rootTrees = MiqNativeMountManager.mountVolumes

  if rootTrees.nil? || rootTrees.empty?
    puts "No root filesystems detected"
    exit
  end

  $miqOut = $stdout
  rootTrees.each do |r|
    r.toXml(nil)
  end

  exit

  rootTree = rootTrees[0]

  if rootTree.guestOS == "Linux"
    puts
    puts "Files in /:"
    rootTree.dirForeach("/") { |f| puts "\t#{f}" }

    # puts
    # puts "All files in /test_mount:"
    # rootTree.findEach("/test_mount") { |f| puts "\t#{f}" }
    #
    # tdn = File.join("/test_mount", dn)
    # tfn = File.join(tdn, fn)
  elsif rootTree.guestOS == "Windows"
    puts
    puts "Files in C:/"
    rootTree.dirForeach("C:/") { |f| puts "\t#{f}" }

    # ["E:/", "F:/"].each do |drive|
    #   puts
    #   puts "All files in #{drive}"
    #   rootTree.findEach(drive) { |f| puts "\t#{f}" }
    # end
    #
    # tdn = File.join("F:/", dn)
    # tfn = File.join(tdn, fn + ".txt")
  else
    puts "Unknown guest OS: #{rootTree.guestOS}"
  end

  puts
  puts "*** Payloads:"
  rootTree.payloads.each { |p| puts "\t#{p.dobj.devFile}" }

  # puts
  # puts "*** Creating Directory: #{tdn}"
  # rootTree.dirMkdir(tdn)
  # puts "*** Creating file: #{tfn}"
  # rootTree.copyIn(".", tdn, true)
  # fo = rootTree.fileOpen(tfn, "w")
  # fo.write(tstring)
  # fo.close
  # ip = rootTree.internalPath(tfn)
  # puts "\tInternal path: #{ip}"
  # puts "Contents:"
  # `cat #{ip}`.each { |l| puts "\t#{l}" }
  # puts "End contents"
  # puts "*** Copied files:"
  # rootTree.findEach(tdn) { |f| puts "\t#{f}" }

  rootTrees.each(&:umount)
end
