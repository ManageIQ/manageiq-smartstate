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
  def self.glob(glob_pattern, fs, flags = 0)
    @fs = fs
    begin
    search_path, specified_path, glob = dir_and_glob(glob_pattern)
    $log.debug "dir_and_glob(#{glob_pattern}) returned \"#{search_path}\", \"#{specified_path}\", and \"#{glob}\""

    unless @fs.fileExists?(search_path)
      return [] unless block_given?
      return false
    end

    ra = [] unless block_given?
    find(search_path, glob_depth(glob)) do |p|
      $log.debug "find(#{search_path}, #{glob_depth(glob)}) returned #{p}"
      next if p == search_path

      if search_path == File::SEPARATOR
        p.sub!(File::SEPARATOR, "")
      else
        p.sub!("#{search_path}#{File::SEPARATOR}", "")
      end

      next if p == ""
      next unless File.fnmatch(glob, p, flags)

      p = File.join(specified_path, p) if specified_path
      block_given? ? yield(p) : ra << p
    end
    rescue Exception => err
      $log.info "Exception #{err}"
      $log.debug err.backtrace.join("\n")
    end
    block_given? ? false : ra.sort_by(&:downcase)
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
    raise SystemCallError.new(path, Errno::ENOENT::Errno) unless @fs.fileExists?(path)
    if @fs.fileExists?(path)
      $log.debug "Path #{path} exists."
    else
      $log.debug "Path #{path} does NOT exist."
    end
    $log.debug  "max_depth is #{max_depth}"

    block_given? || (return enum_for(__method__, path, max_depth))

    depths = [0]
    paths  = [path.dup]

    while (file = paths.shift)
      depth = depths.shift
      catch(:prune) do
        yield file.dup.taint
        if @fs.fileExists?(file) && @fs.fileDirectory?(file)
          $log.debug "find: while-loop file #{file} is a directory, depth is #{depth}, max_depth is #{max_depth}"
          next if depth + 1 > max_depth if max_depth
          begin
            files = @fs.dirEntries(file)
            $log.debug "find: while-loop files are #{files}"
          rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
            $log.info "find: while-loop @fs.dirEntries #{file} returned an error"
            next
          rescue Exception => err
            $log.info "find: unexpected Exception #{err} processing #{file}"
            $log.debug err.backtrace.join("\n")
          end
          files.sort!
          files.reverse_each do |f|
            next if f == "." || f == ".."
            f = File.join(file, f)
            paths.unshift f.untaint
            depths.unshift depth + 1
          end
        end
      end
    end
  end

  GLOB_CHARS = '*?[{'
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
    stripped_path  = glob_pattern.sub(/^[a-zA-Z]:/, "")
    glob_path      = Pathname.new(stripped_path)
    $log.debug "dir_and_glob: glob_pattern is #{glob_pattern}, stripped pattern is #{stripped_path}"

    if glob_path.absolute?
      $log.debug "dir_and_glob: glob_path #{glob_path} is absolute"
      search_path    = File::SEPARATOR
      specified_path = File::SEPARATOR
    else
      $log.debug "dir_and_glob: glob_path #{glob_path} is relative"
      search_path    = Dir.getwd
      specified_path = nil
    end
    $log.debug "dir_and_glob: search_path is #{search_path}, specified_path is #{specified_path}"

    components = glob_path.each_filename.to_a
    while (comp = components.shift)
      if glob_str?(comp)
        components.unshift(comp)
        break
      end
      search_path = File.join(search_path, comp)
      if specified_path
        specified_path = File.join(specified_path, comp)
      else
        specified_path = comp
      end
    end
    return File.expand_path(search_path, "/"), specified_path, File.join(components)
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
