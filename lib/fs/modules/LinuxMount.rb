require 'fs/MiqFS/MiqFS'

module LinuxMount
  FSTAB_FILE_NAME = "/etc/fstab"

  def fs_init
    @guestOS = "Linux"

    @rootFS = MiqFS.getFS(@rootVolume)
    raise "LinuxMount: could not mount root volume" unless @rootFS

    assign_device_letters
    fs_spec_hash = build_fstab_spec
    build_os_names
    build_mount_point_tree(fs_spec_hash)
  end

  #
  # Given a path to a file, return true if it's a symbolic link.
  # Otherwise, return false.
  #
  def fileSymLink?(p)
    #
    # We can't just expand the links in the whole path,
    # because then, the target file will no longer be a link.
    # So, we expand the path to the target file, then open
    # the target file through that path to obtain the link data.
    #
    np = normalizePath(p)
    d = File.dirname(np)
    f = File.basename(np)

    # Expand the path to the target file.
    exp_dir = expandLinks(d)

    # Get the file system where the target file resides, and it's local path.
    fs, lp = getFsPathBase(File.join(exp_dir, f))
    fs.fileSymLink?(lp)
  end

  #
  # Given a path to a symbolic link, return the full
  # path to where the link points.
  #
  def getLinkPath(p)
    #
    # We can't just expand the links in the whole path,
    # because then, the target file will no longer be a link.
    # So, we expand the path to the target file, then open
    # the target file through that path to obtain the link data.
    #
    np = normalizePath(p)
    d = File.dirname(np)
    f = File.basename(np)

    # Expand the path to the target file.
    exp_dir = expandLinks(d)

    # Get the file system where the target file resides, and it's local path.
    fs, lp = getFsPathBase(File.join(exp_dir, f))
    # Read the link data from the file, through its file system.
    sp = getSymLink(fs, lp)
    # Construct and return the full path to the link target.
    return(sp) if sp[0, 1] == '/'
    normalizePath(File.join(exp_dir, sp))
  end

  private

  def assign_device_letters
    #
    # Assign device letters to all ide and scsi devices,
    # even if they're not visible volumes. We need to do
    # this to assign the proper device names to visible
    # devices.
    #
    sdLetter = 'a'
    ideMap   = {"ide0:0" => "a", "ide0:1" => "b", "ide1:0" => "c", "ide1:1" => "d"}
    @devHash = {}
    @vmConfig.getAllDiskKeys.each do |dk|
      if dk =~ /^ide.*$/
        @devHash[dk] = "/dev/hd" + ideMap[dk]
      elsif dk =~ /^scsi.*$/
        @devHash[dk] = "/dev/sd" + sdLetter
        sdLetter.succ!
      end
      $log.debug("LinuxMount: devHash[#{dk}] = #{devHash[dk]}") if $log.debug
    end
  end

  def build_fstab_spec
    #
    # Build hash for fstab fs_spec look up.
    #
    fs_spec_hash = {}
    @volumes.each do |v|
      $log.debug("LinuxMount: Volume = #{v.dInfo.localDev} (#{v.dInfo.hardwareId}, partition = #{v.partNum})") if $log.debug
      if v == @rootVolume
        fs = @rootFS
      else 
        (fs = MiqFS.getFS(v)) || next
      end
      @allFileSystems << fs

      fs_spec_hash.merge!(add_fstab_entries(fs, v))
    end
    fs_spec_hash
  end

  def add_fstab_entries(fs, v)
    fs_spec_hash = add_fstab_fs_entries(fs)

    if v.dInfo.lvObj
      fs_spec_hash.merge!(add_fstab_logical_entries(fs, v))
    else
      fs_spec_hash.merge!(add_fstab_physical_entry(fs, v))
    end
    fs_spec_hash
  end

  def add_fstab_fs_entries(fs)
    #
    # Specific file systems can be identified by fs UUID
    # or file system volume label.
    #
    fs_spec_fs_hash = {}
    unless fs.volName.empty?
      $log.debug("LinuxMount: adding \"LABEL=#{fs.volName}\" & \"LABEL=/#{fs.volName}\" to hash") if $log.debug
      fs_spec_fs_hash["LABEL=#{fs.volName}"]  = fs
      fs_spec_fs_hash["LABEL=/#{fs.volName}"] = fs
    end
    unless fs.fsId.empty?
      $log.debug("LinuxMount: adding \"UUID=#{fs.fsId}\" to fs_spec_hash") if $log.debug
      fs_spec_fs_hash["UUID=#{fs.fsId}"] = fs
    end
    fs_spec_fs_hash
  end

  def add_fstab_logical_entries(fs, v)
    #
    # Logical volumes can be identified by their lv specific
    # entries under /dev.
    #
    lv_name = v.dInfo.lvObj.lvName
    vg_name = v.dInfo.lvObj.vgObj.vgName
    fs_spec_logical_hash = {}
    fs_spec_logical_hash["/dev/#{vg_name}/#{lv_name}"] = fs
    fs_spec_logical_hash["/dev/mapper/#{vg_name.gsub('-', '--')}-#{lv_name.gsub('-', '--')}"] = fs
    fs_spec_logical_hash["UUID=#{v.dInfo.lvObj.lvId}"] = fs
    $log.debug("LinuxMount: Volume = #{v.dInfo.localDev}, partition = #{v.partNum} is a logical volume") if $log.debug
    fs_spec_logical_hash
  end

  def add_fstab_physical_entry(fs, v)
    #
    # Physical volumes are identified by entries under
    # /dev based on OS hardware scan.
    # TODO: support physical volume UUIDs
    #
    fs_spec_physical_hash = {}
    $log.debug("LinuxMount: v.dInfo.hardwareId = #{v.dInfo.hardwareId}") if $log.debug
    if v.partNum.zero?
      fs_spec_physical_hash[@devHash[v.dInfo.hardwareId]] = fs
    else
      fs_spec_physical_hash[@devHash[v.dInfo.hardwareId] + v.partNum.to_s] = fs
    end
    fs_spec_physical_hash
  end

  def build_os_names
    #
    # Assign OS-specific names to all physical volumes.
    #
    @osNames = {}
    @volMgr.allPhysicalVolumes.each do |v|
      if $log.debug?
        $log.debug "LinuxMount: v.dInfo.hardwareId = #{v.dInfo.hardwareId}"
        $log.debug "LinuxMount: v.partNum.to_s = #{v.partNum}"
        $log.debug "LinuxMount: @devHash[v.dInfo.hardwareId] = #{@devHash[v.dInfo.hardwareId]}"
      end
      @osNames[v.dInfo.hardwareId + ':' + v.partNum.to_s] = @devHash[v.dInfo.hardwareId] + v.partNum.to_s
    end
  end

  def build_mount_point_tree(fs_spec_hash)
    #
    # Build a tree of file systems and their associated mont points.
    #
    root_added = false
    @mountPoints = {}
    $log.debug("LinuxMount: processing #{FSTAB_FILE_NAME}") if $log.debug
    @rootFS.fileOpen(FSTAB_FILE_NAME, &:read).each_line do |fstl|
      $log.debug("LinuxMount: fstab line: #{fstl}") if $log.debug
      root_added = true if do_fstab_line(fstl, fs_spec_hash) == '/'
    end
    saveFs(@rootFS, "/", "ROOT") unless root_added
  end

  def do_fstab_line(fstab_line, fs_spec_hash)
    return if fstab_line =~ /^#.*$/ || fstab_line =~ /^\s*$/
    fs_spec, mt_point = fstab_line.strip.split(/\s+/)
    return if fs_spec == "none" || mt_point == "swap"
    return unless (fs = fs_spec_hash[fs_spec])
    $log.debug("LinuxMount: Adding fs_spec: #{fs_spec}, mt_point: #{mt_point}") if $log.debug
    addMountPoint(mt_point, fs, fs_spec)
    mt_point
  end

  def normalizePath(p)
    # When running on windows, File.expand_path will add a drive letter.
    # Remove it if it's there.
    np = File.expand_path(p, @cwd).gsub(/^[a-zA-Z]:/, "")
    # puts "LinuxMount::normalizePath: p = #{p}, np = #{np}"
    (np)
  end

  class PathNode
    attr_accessor :children, :fs

    def initialize
      @children = {}
      @fs = nil
    end
  end # def PathNode

  #
  # Add the file system to the mount point tree.
  #
  def addMountPoint(mp, fs, fsSpec)
    saveFs(fs, mp, fsSpec)
    return if mp == '/'
    path = mp.split('/')
    path.delete("")
    h = @mountPoints
    tn = nil
    path.each do |d|
      h[d] = PathNode.new unless h[d]
      tn = h[d]
      h = h[d].children
    end
    tn.fs = fs if tn
  end

  #
  # Expand symbolic links and perform mount indirection look up.
  #
  def getFsPath(path)
    if path.kind_of? Array
      if path.length == 0
        localPath = @cwd
      else
        localPath = normalizePath(path[0])
      end
    else
      localPath = normalizePath(path)
    end

    getFsPathBase(expandLinks(localPath))
    # getFsPathBase(path)
  end

  #
  # Mount indirection look up.
  # Given a path, return its corresponding file system
  # and the part of the path relative to that file system.
  # It assumes symbolic links have already been expanded.
  #
  def getFsPathBase(path)
    if path.kind_of? Array
      if path.length == 0
        localPath = @cwd
      else
        localPath = normalizePath(path[0])
      end
    else
      localPath = normalizePath(path)
    end

    fs = @rootFS
    p = localPath.split('/')
    p.delete("")

    h = @mountPoints
    while d = p.shift
      return fs, localPath unless h[d]
      if tfs = h[d].fs
        fs = tfs
        localPath = '/' + p.join('/')
      end
      h = h[d].children
    end
    return fs, localPath
  end

  #
  # Expand symbolic links in the path.
  # This must be done here, because a symlink in one file system
  # can point to a file in another filesystem.
  #
  def expandLinks(p)
    cp = '/'
    components = p.split('/')
    components.shift if components[0] == "" # root

    #
    # For each component of the path, check to see
    # if it's a symbolic link. If so, expand it
    # relative to its base directory.
    #
    components.each do |c|
      ncp = File.join(cp, c)
      #
      # Each file system know how to check for,
      # and read its own links.
      #
      fs, lp = getFsPathBase(ncp)
      if fs.fileSymLink?(lp)
        sl = getSymLink(fs, lp)
        if sl[0, 1] == '/'
          cp = sl
        else
          cp = File.join(cp, sl)
        end
      else
        cp = ncp
      end
    end
    (cp)
  end

  def getSymLink(fs, p)
    fs.fileOpen(p, &:read)
  end
end # module LinuxMount
