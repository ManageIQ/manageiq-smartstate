module FindClassMethods
  # Return directory entries matching specified glob pattern
  #
  # @param glob_pattern [String] pattern to match
  # @param flags [Integer] file match flags
  # @yield block invoked with each match if specified
  #
  # @see VfsRealFile.fnmatch
  # @see FindClassMethods#dir_and_glob which does most of the work regarding globbing
  # @see FindClassMethods#find which retrieves stats information & dir entries for found files
  #
  def self.glob(glob_pattern, filesys, flags = 0)
    @fs = filesys
    return [] unless (glob = dir_and_glob(glob_pattern))

    ra = []
    find(@search_path, glob_depth(glob)) do |p|
      p = check_file(p, glob, flags)
      p && block_given? ? yield(p) : ra << p
    end
    ra.sort_by(&:downcase)
  end

  #
  # Determine if the file returned from "find" will be used or skipped.
  #
  def self.check_file(file, glob, flags)
    return nil if file == @search_path

    if @search_path == File::SEPARATOR
      file.sub!(File::SEPARATOR, "")
    else
      file.sub!("#{@search_path}#{File::SEPARATOR}", "")
    end

    return nil if file == "" || !File.fnmatch(glob, file, flags)

    @specified_path ? File.join(@specified_path, file) : file
  end

  #
  # Modified version of Find.find:
  # - Accepts only a single path.
  # - Can be restricted by depth - optimization for glob searches.
  #
  # @param path [String] starting directory of the find
  # @param max_depth [Integer] max number of levels to decend befroelookup
  # @yield files found
  #
  def self.find(path, max_depth = nil)
    block_given? || (return enum_for(__method__, path, max_depth))

    depths = [0]
    paths  = [path.dup]

    while (file = paths.shift)
      depth = depths.shift
      yield file.dup.taint
      next if max_depth && depth + 1 > max_depth

      get_dir_entries(file).each do |f|
        f = File.join(file, f)
        paths.unshift f.untaint
        depths.unshift depth + 1
      end
    end
  end

  def self.get_dir_entries(directory)
    return [] unless @fs.fileExists?(directory) && @fs.fileDirectory?(directory)

    files = @fs.dirEntries(directory)
    files.difference([".", ".."])
    files.sort!
    files.reverse_each
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
    $log.info "find: while-loop @fs.dirEntries #{directory} returned an error"
    []
  end

  GLOB_CHARS = '*?[{'.freeze
  def self.glob_str?(str)
    str.gsub(/\\./, "X").count(GLOB_CHARS) != 0
  end

  # Returns files matching glob pattern
  #
  # @api private
  # @param glob_pattern [String,Regex] pattern to search for
  # @return [String] paths to files found
  #
  def self.dir_and_glob(glob_pattern)
    stripped_path   = glob_pattern.sub(/^[a-zA-Z]:/, "")
    glob_path       = Pathname.new(stripped_path)
    @search_path    = File::SEPARATOR
    @specified_path = File::SEPARATOR

    unless glob_path.absolute?
      @search_path    = Dir.getwd
      @specified_path = nil
    end

    components   = path_components(glob_path)
    @search_path = File.expand_path(@search_path, "/")
    @fs.fileExists?(@search_path) ? File.join(components) : nil
  end

  def self.path_components(glob_path)
    components = glob_path.each_filename.to_a
    while (comp = components.shift)
      if glob_str?(comp)
        components.unshift(comp)
        break
      end
      @search_path = File.join(@search_path, comp)
      @specified_path = @specified_path ? File.join(@specified_path, comp) : comp
    end
    components
  end

  # Return max levels which glob pattern may resolve to
  #
  # @api private
  # @param glob_pattern [String,Regex] pattern to search for
  # @return [Integer] max levels which pattern may match
  def self.glob_depth(glob_pattern)
    path_components = Pathname(glob_pattern).each_filename.to_a
    return nil if path_components.include?('**')

    path_components.length
  end
end
