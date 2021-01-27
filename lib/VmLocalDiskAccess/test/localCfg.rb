require 'util/miq-xml'
require 'metadata/VmConfig/VmConfig'
require 'VolumeManager/MiqNativeVolumeManager'
require 'fs/MiqMountManager'
require 'awesome_spawn'

module MiqNativeMountManager
  def self.mountVolumes
    lshwXml = AwesomeSpawn.run!("lshw", :params => ["-xml"], :combined_output => true).output
    nodeHash = Hash.new { |h, k| h[k] = [] }
    doc = MiqXml.load(lshwXml)
    doc.find_match("//node").each { |n| nodeHash[n.attributes["id"].split(':', 2)[0]] << n }

    hardware = ""

    nodeHash["disk"].each do |d|
      diskid = d.find_first('businfo').get_text.to_s
      next unless diskid
      sn = d.find_first('size')
      # If there's no size node, assume it's a removable drive.
      next unless sn
      busType, busAddr = diskid.split('@', 2)
      if busType == "scsi"
        f1, f2 = busAddr.split(':', 2)
        f2 = f2.split('.')[1]
        busAddr = "#{f1}:#{f2}"
      else
        busAddr['.'] = ':'
      end
      diskid = busType + busAddr
      filename = d.find_first('logicalname').get_text.to_s
      hardware += "#{diskid}.present = \"TRUE\"\n"
      hardware += "#{diskid}.filename = \"#{filename}\"\n"
    end

    cfg = VmConfig.new(hardware)
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

  rootTree = rootTrees[0]

  if rootTree.guestOS == "Linux"
    puts
    puts "Files in /:"
    rootTree.dirForeach("/") { |f| puts "\t#{f}" }

    puts
    puts "All files in /test_mount:"
    rootTree.findEach("/test_mount") { |f| puts "\t#{f}" }
  elsif rootTree.guestOS == "Windows"
    puts
    puts "Files in C:/"
    rootTree.dirForeach("C:/") { |f| puts "\t#{f}" }

    ["E:/", "F:/"].each do |drive|
      puts
      puts "All files in #{drive}"
      rootTree.findEach(drive) { |f| puts "\t#{f}" }
    end
  else
    puts "Unknown guest OS: #{rootTree.guestOS}"
  end
end
