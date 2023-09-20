require 'sys-uname'
require 'manageiq/gems/pending'
require 'util/miq-system'

if Sys::Platform::IMPL == :linux && MiqSystem.arch == :x86_64
  require 'linux_block_device'
  require 'disk/modules/RawBlockIO'
end

module MiqLargeFile
  def self.open(file_name, flags)
    if Sys::Platform::IMPL == :linux && MiqLargeFileStat.new(file_name).blockdev?
      RawBlockIO.new(file_name, flags)
    else
      MiqLargeFileOther.new(file_name, flags)
    end
  end

  def self.size(file_name)
    f = open(file_name, "r")
    s = f.size
    f.close
    s
  end

  # For camcorder interposition.
  class MiqLargeFileStat
    def initialize(file_name)
      @file_name = file_name
    end

    def blockdev?
      File.stat(@file_name).blockdev?
    end
  end

  class MiqLargeFileOther < File
    def write(buf, _len)
      super(buf)
    end

    def size
      return stat.size unless stat.blockdev?
      LinuxBlockDevice.size(fileno)
    end
  end
end
