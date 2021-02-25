require 'disk/modules/MiqLargeFile'
require 'disk/modules/miq_disk_common'
require 'binary_struct'
require 'memory_buffer'
require 'zlib'

module VMWareSparseDisk
  SPARSE_MAGIC_NUMBER = "VMDK".unpack1("L>") # 0x564d444b

  SPARSE_EXTENT_HEADER = BinaryStruct.new([
    # the magic number is used to verify the validity of each sparse extent when the extent is opened
    'L',  'magicNumber',          # should be SPARSE_MAGIC_NUMBER

    'L',  'version',              # the version number can be 1 or 2

    # SparseExtentHeader is stored on disk in little-endian byte order, so if you examine the first eight bytes of a VMDK file,
    # you see either:
    #   'K' 'D' 'M' 'V' 0x01 0x00 0x00 0x00
    #   'K' 'D' 'M' 'V' 0x02 0x00 0x00 0x00

    # flags contains the following bits of information.
    'L',  'flags',                # bit 0:  valid new line detection test
                                  # bit 1:  redundant grain table will be used
                                  # bit 2:  zeroed‐grain GTE will be used
                                  # bit 16: the grains are compressed. The type of compression is described by compressAlgorithm.
                                  # bit 17: there are markers in the virtual disk to identify every block of metadata or data and
                                  #         the markers for the virtual machine data contain logical block addressing (LBA)

    'Q',  'capacity',             # the capacity of this extent in sectors — should be a multiple of the grain size.
    'Q',  'grainSize',            # the size of a grain in sectors. It must be a power of 2 and must be greater than 8 (4KB).
    'Q',  'descriptorOffset',     # the offset of the embedded descriptor in the extent. It is expressed in sectors.
                                  #   If the descriptor is not embedded, all the extents in the link have the descriptor offset field set to 0.
    'Q',  'descriptorSize',       # is valid only if descriptorOffset is non-zero. It is expressed in sectors.
    'L',  'numGTEsPerGT',         # the number of entries in a grain table. The value of this entry for VMware virtual disks is 512.
    'Q',  'rgdOffset',            # points to the redundant level 0 of metadata. It is expressed in sectors.
    'Q',  'gdOffset',             # points to the level 0 of metadata. It is expressed in sectors
    'Q',  'overHead',             # the number of sectors occupied by the metadata.
    'C',  'uncleanShutdown',      # set to FALSE when VMware software closes an extent.
                                  #   After an extent has been opened, VMware software checks for the value of uncleanShutdown.
                                  #   If it is TRUE, the disk is automatically checked for consistency.
                                  #   uncleanShutdown is set to TRUE after this check has been performed.
                                  #   Thus, if the software crashes before the extent is closed, this boolean is found to be set
                                  #      to TRUE the next time the virtual machine is powered on

    # 4 entries are used to detect when an extent file has been corrupted by transferring it using FTP in text mode.
    #   The entries should be initialized with the following values:
    'a1', 'singleEndLineChar',    # should be '\n'
    'a1', 'nonEndLineChar',       # should be ' '
    'a1', 'doubleEndLineChar1',   # should be '\r'
    'a1', 'doubleEndLineChar2',   # should be '\n'

    # describes the type of compression used to compress every grain in the virtual disk.
    #   If bit 16 of the field flags is not set, compressAlgorithm is COMPRESSION_NONE.
    #   The deflate algorithm is described in RFC 1951.
    'S',  'compressAlgorithm',

    # 'a433', 'padding'
  ])
  SIZEOF_SPARSE_EXTENT_HEADER = SPARSE_EXTENT_HEADER.size

  SPARSE_EXTENT_COMPRESSED_GRAIN_HEADER = BinaryStruct.new([
    'Q',  'lba',     # offset in the virtual disk where the block of compressed data is located
    'L',  'size',    # size of the compressed data in bytes
                     # the rest is data compressed with RFC 1951
  ])
  SIZEOF_SPARSE_EXTENT_COMPRESSED_GRAIN_HEADER = SPARSE_EXTENT_COMPRESSED_GRAIN_HEADER.size

  BYTES_PER_SECTOR = 512
  GDE_SIZE         = 4
  GDES_PER_GD      = BYTES_PER_SECTOR / GDE_SIZE
  GD_AT_END        = 0xFFFFFFFFFFFFFFFF
  GTE_SIZE         = 4
  GTES_PER_GT      = 512

  COMPRESSION_NONE    = 0
  COMPRESSION_DEFLATE = 1

  FLAG_MASK_VALID_NEWLINE_DETECTION_TEST = 0x00010000
  FLAG_MASK_USE_REDUNDANT_GRAIN_TABLE    = 0x00020000
  FLAG_MASK_USE_ZEROED_GRAIN_GTE         = 0x00040000
  FLAG_MASK_COMPRESSED                   = 0x00000001
  FLAG_MASK_METADATA_MARKERS_USED        = 0x00000002

  def d_init
    self.diskType = "VMWare Sparse"
    self.blockSize = BYTES_PER_SECTOR
    fileMode = MiqDiskCommon.file_mode(dInfo)
    @vmwareSparseDisk_file = MiqLargeFile.open(dInfo.fileName, fileMode)
    buf = @vmwareSparseDisk_file.read(SIZEOF_SPARSE_EXTENT_HEADER)
    @sparseHeader = OpenStruct.new(SPARSE_EXTENT_HEADER.decode(buf))

    #
    # If the grain directory sector number value is GD_AT_END and the "use redundant grain table" flag is set,
    #  then the SPARSE_EXTENT_HEADER is located in the footer.
    # The footer is a secondary file header stored at offset -1024 relative from the end of the file (stream)
    #  that contains the correct grain directory sector number value.
    #
    if flag_set?(@sparseHeader.flags, FLAG_MASK_USE_REDUNDANT_GRAIN_TABLE) && (GD_AT_END == @sparseHeader.gdOffset)
      @vmwareSparseDisk_file.seek(-2 * BYTES_PER_SECTOR, IO::SEEK_END)
      buf = @vmwareSparseDisk_file.read(SIZEOF_SPARSE_EXTENT_HEADER)
      @sparseHeader = OpenStruct.new(SPARSE_EXTENT_HEADER.decode(buf))
    end
    raise "MIQ(VMWareSparseDisk.d_init) Invalid Sparse Extent Header" if @sparseHeader['magicNumber'] != SPARSE_MAGIC_NUMBER

    @grainSize  = @sparseHeader.grainSize
    @grainBytes = @grainSize * BYTES_PER_SECTOR
    @gtCoverage = @sparseHeader.grainSize * @sparseHeader.numGTEsPerGT
    @capacity   = @sparseHeader.capacity * BYTES_PER_SECTOR
    @flags      = flags_to_hash(@sparseHeader.flags)

    if @flags[:metadata_markers_used]
      raise NotImplementedError, "MIQ(VMWareSparseDisk.d_init) Stream-Optimized Compressed Format is NOT supported"
    else
      initialize_without_markers
    end
  end

  def getBase
    self
  end

  def d_read(pos, len, offset = 0)
    gnStart, goStart = grainPos(pos - offset)
    gnEnd,   goEnd   = grainPos(pos + len - offset)

    bytes_read = 0
    buffer = ''
    (gnStart..gnEnd).each do |grain_number|
      offset_in_grain = 0
      length_in_grain = @grainBytes

      if grain_number == gnStart
        offset_in_grain  = goStart
        length_in_grain -= goStart
      end

      length_in_grain -= (@grainBytes - goEnd) if grain_number == gnEnd

      buffer << read_grain(grain_number, offset_in_grain, length_in_grain, pos + bytes_read)
      bytes_read += length_in_grain
    end
    raise "Read Error (requested length=#{len}, read length=#{bytes_read})" if bytes_read != len

    buffer
  end

  def d_write(pos, buf, len, offset = 0)
    gnStart, goStart = grainPos(pos - offset)
    gnEnd, goEnd = grainPos(pos + len - offset)

    if gnStart == gnEnd
      gte      = getGTE(gnStart)
      grainPos = gte * BYTES_PER_SECTOR
      grainPos = allocGrain(gnStart) if gte == 0
      @vmwareSparseDisk_file.seek(grainPos + goStart, IO::SEEK_SET)
      return @vmwareSparseDisk_file.write(buf, len)
    end

    bytesWritten = 0
    (gnStart..gnEnd).each do |gn|
      so = 0
      l = @grainBytes

      if gn == gnStart
        so = goStart
        l -= so
      end
      if gn == gnEnd
        l -= (@grainBytes - goEnd)
      end

      gte = getGTE(gn)
      gp  = gte * BYTES_PER_SECTOR
      gp  = allocGrain(gn) if gte == 0
      @vmwareSparseDisk_file.seek(gp + so, IO::SEEK_SET)
      bytesWritten += @vmwareSparseDisk_file.write(buf[bytesWritten, l], l)
    end
    bytesWritten
  end

  def d_close
    @vmwareSparseDisk_file.close
  end

  # Disk size in sectors.
  def d_size
    @capacity / @blockSize
  end

  private

  def initialize_without_markers
    #
    # Seek to start of the grain directory.
    #
    @vmwareSparseDisk_file.seek(@sparseHeader.gdOffset * blockSize, IO::SEEK_SET)

    #
    # Read the first grain directory entry to get the offset to the start of
    # the grain tables.
    #
    buf = @vmwareSparseDisk_file.read(BYTES_PER_SECTOR)
    @grainDirectory = GDES_PER_GD.times.map { |index| buf[index, GDE_SIZE].unpack1('L') }

    #
    # In a Hosted Sparse Extent, all the grain tables are created when the sparse extent is created,
    # hence the grain directory is technically not necessary but has been kept for legacy reasons.
    # If you disregard the abstraction provided by the grain directory, you can redefine grain tables
    # as blocks of grain tables of arbitrary size.  If there were no grain directories, there would
    # be no need to impose a length of 512 entries per grain table.
    #
    # However this approach does not work for Stream-Optimized Compresses Sparse Extents.
    #
    @grainTableBase = @grainDirectory[0] * blockSize
  end

  def flag_set?(flags, mask)
    !(flags & mask).zero?
  end

  def flags_to_hash(flags)
    hash                                = {}
    hash[:compressed]                   = flag_set?(flags, FLAG_MASK_COMPRESSED)
    hash[:metadata_markers_used]        = flag_set?(flags, FLAG_MASK_METADATA_MARKERS_USED)
    hash[:use_redundant_grain_table]    = flag_set?(flags, FLAG_MASK_USE_REDUNDANT_GRAIN_TABLE)
    hash[:use_zeroed_grain_gte]         = flag_set?(flags, FLAG_MASK_USE_ZEROED_GRAIN_GTE)
    hash[:valid_newline_detection_test] = flag_set?(flags, FLAG_MASK_VALID_NEWLINE_DETECTION_TEST)
    hash
  end

  def grainPos(pos)
    sector = pos / @grainBytes
    offset = pos - (sector * @grainBytes)
    return sector, offset
  end

  def getGDE(gn)
    gd_index = (gn / @gtCoverage).floor
    gde      = @grainDirectory[gd_index]
    gde
  end

  def getGTE(gn)
    gde = getGDE(gn)
    gt  = getGrainTable(gde)
    gt_index = ((gn % @gtCoverage) / @grainSize).floor
    gte = gt[gt_index]
    gte
  end

  def allocGrain(gn)
    sector = findFreeSector; byte = gn * @grainBytes
    buf = @dInfo.parent.nil? ? MemoryBuffer.create(@grainBytes) : @dInfo.parent.d_read(byte, @grainBytes)
    seekGTE(gn)
    @vmwareSparseDisk_file.write([sector].pack('L'), GTE_SIZE)
    @vmwareSparseDisk_file.seek(sector * blockSize, IO::SEEK_SET)
    @vmwareSparseDisk_file.write(buf, @grainBytes)
    sector * blockSize
  end

  def parseGrainTable(buffer)
    GTES_PER_GT.times.map { |index| buffer[index, GTE_SIZE].unpack1('L') }
  end

  def readGrainTable(gde)
    @vmwareSparseDisk_file.seek(gde * BYTES_PER_SECTOR, IO::SEEK_SET)
    parseGrainTable(@vmwareSparseDisk_file.read(GTES_PER_GT * GTE_SIZE))
  end

  def getGrainTable(gde)
    @grain_tables      ||= {}
    @grain_tables[gde] ||= readGrainTable(gde)
  end

  def seekGTE(gn)
    gteOffset = @grainTableBase + (gn * GTE_SIZE)
    @vmwareSparseDisk_file.seek(gteOffset, IO::SEEK_SET)
  end

  def findFreeSector
    if @freeSector.nil?
      numGrains = @sparseHeader.capacity / @grainSize
      @vmwareSparseDisk_file.seek(@grainTableBase, IO::SEEK_SET)
      @freeSector = 0
      numGrains.times do |_i|
        last = @vmwareSparseDisk_file.read(GTE_SIZE).unpack('L')[0]
        @freeSector = last if last > @freeSector
      end
    end
    @freeSector += @grainSize
    raise "Disk full." if @freeSector * blockSize > @capacity
    @freeSector
  end

  def read_compressed_grain(grain_offset)
    @vmwareSparseDisk_file.seek(grain_offset, IO::SEEK_SET)
    buffer = @vmwareSparseDisk_file.read(SIZEOF_SPARSE_EXTENT_COMPRESSED_GRAIN_HEADER)
    compressed_grain_header = SPARSE_EXTENT_COMPRESSED_GRAIN_HEADER.decode(buffer)
    buffer = @vmwareSparseDisk_file.read(compressed_grain_header['size'])
    Zlib::Inflate.inflate(buffer)
  end

  def read_grain_from_disk(gte, offset, length)
    grain_location = gte * BYTES_PER_SECTOR

    if @flags[:compressed]
      buffer = read_compressed_grain(grain_location)
      buffer[offset, length]
    else
      @vmwareSparseDisk_file.seek(grain_location + offset, IO::SEEK_SET)
      @vmwareSparseDisk_file.read(length)
    end
  end

  def read_grain(grain_number, offset, length, parent_offset)
    gte = getGTE(grain_number)

    #
    # when GTE >  1 - all reads: from the sparse disk
    # when GTE is 0 - reads with no parent: return 0s
    #               - reads with    parent: read from parent
    # when GTE is 1 - all reads: return 0s
    #
    if gte > 1
      read_grain_from_disk(gte, offset, length)
    elsif gte == 0 && @dInfo.parent
      @dInfo.parent.d_read(parent_offset, length)
    else
      MemoryBuffer.create(length)
    end
  end
end
