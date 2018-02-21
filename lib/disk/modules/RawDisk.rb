require 'disk/modules/MiqLargeFile'
require 'disk/modules/miq_disk_common'

module RawDisk
  def d_init
    self.diskType = "Raw"
    self.blockSize = 512

    fileMode = MiqDiskCommon.file_mode(dInfo)

    @dOffset = dInfo.offset
    @rawDisk_file = MiqLargeFile.open(dInfo.fileName, fileMode)
  end

  def getBase
    self
  end

  def d_read(pos, len, offset = 0)
    pos += @dOffset if @dOffset
    @rawDisk_file.seek(pos - offset, IO::SEEK_SET)
    @rawDisk_file.read(len)
  end

  def d_write(pos, buf, len, offset = 0)
    pos += @dOffset if @dOffset
    @rawDisk_file.seek(pos - offset, IO::SEEK_SET)
    @rawDisk_file.write(buf, len)
  end

  def d_close
    @rawDisk_file.close
  end

  # Disk size in sectors.
  def d_size
    @rawDisk_file.size / @blockSize
  end
end
