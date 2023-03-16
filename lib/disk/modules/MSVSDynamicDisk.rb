require 'disk/modules/MSCommon'
require 'disk/modules/miq_disk_common'

module MSVSDynamicDisk
  def d_init
    self.diskType = "MSVS Dynamic"
    self.blockSize = MSCommon::SECTOR_LENGTH
    fileMode = MiqDiskCommon.file_mode(dInfo)
    @ms_disk_file = MiqLargeFile.open(dInfo.fileName, fileMode)
    MSCommon.d_init_common(dInfo, @ms_disk_file)
  end

  def getBase
    self
  end

  def d_read(pos, len)
    MSCommon.d_read_common(pos, len)
  end

  def d_write(pos, buf, len)
    MSCommon.d_write_common(pos, buf, len)
  end

  def d_close
    @ms_disk_file.close
  end

  def d_size
    MSCommon.d_size_common
  end
end # module
