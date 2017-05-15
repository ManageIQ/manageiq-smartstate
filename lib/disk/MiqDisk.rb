require 'binary_struct'
require 'disk/DiskProbe'

class MiqDisk
  attr_accessor :diskType, :dInfo, :blockSize, :pvObj, :fs
  attr_reader   :lbaStart, :lbaEnd, :startByteAddr, :endByteAddr, :partType, :partNum, :size, :hwId, :logName

  def self.getDisk(dInfo, probes = nil)
    $log.debug "MiqDisk::getDisk: baseOnly = #{dInfo.baseOnly}" if $log
    if (dm = DiskProbe.getDiskMod(dInfo, probes))
      d = new(dm, dInfo.clone, 0)
      if dInfo.baseOnly
        $log.debug "MiqDisk::getDisk: baseOnly = true, returning parent: #{d.getBase.dInfo.fileName}" if $log
        $log.debug "MiqDisk::getDisk: child (current) disk file: #{dInfo.fileName}" if $log
        return d.getBase
      else
        $log.debug "MiqDisk::getDisk: baseOnly = false, returning: #{dInfo.fileName}" if $log
      end
      return d
    end
    (nil)
  end

  def self.pushFormatSupportForDisk(disk, probes = nil)
    if (dm = DiskProbe.getDiskModForDisk(disk, probes))
      $log.debug "#{name}.pushFormatSupportForDisk: pushing #{dm.name} onto #{disk.logName}"
      di = disk.dInfo.clone
      di.downstreamDisk = disk
      d = new(dm, di, 0)
      disk.dInfo.upstreamDisk = d
      return d
    end
    $log.debug "#{name}.pushFormatSupportForDisk: no module to push for #{disk.logName}"
    disk
  end

  def initialize(dm, dInfo, pType, *lbaSE)
    extend(dm) unless dm.nil?
    @dModule  = dm
    @dInfo    = dInfo
    @partType = pType
    @partNum  = lbaSE.length == 3 ? lbaSE[2] : 0
    @partitions = nil
    @pvObj    = nil
    @fs     = nil   # the filesystem that resides on this disk

    if dInfo.lvObj
      @logName = "logical volume: #{dInfo.lvObj.vgObj.vgName}/#{dInfo.lvObj.lvName}"
    else
      @logName = "disk file: #{dInfo.fileName}"
    end
    @logName << " (partition: #{@partNum})"
    $log.debug "MiqDisk<#{object_id}> initialize, #{@logName}"

    d_init

    case lbaSE.length
    when 0
      @lbaStart = 0
      @lbaEnd = d_size
    when 1
      @lbaStart = lbaSE[0]
      @lbaEnd = d_size
    else
      @lbaStart = lbaSE[0]
      @lbaEnd = lbaSE[1] + @lbaStart # lbaSE[1] is the partiton size in sectors
    end

    @startByteAddr = @lbaStart * @blockSize
    @endByteAddr = @lbaEnd * @blockSize
    @size = @endByteAddr - @startByteAddr
    @seekPos = @startByteAddr

    @dInfo.diskSig ||= getDiskSig if @partNum == 0 && !@dInfo.baseOnly
    @hwId = "#{@dInfo.hardwareId}:#{@partNum}" if @dInfo.hardwareId
  end

  def pushFormatSupport
    self.class.pushFormatSupportForDisk(self)
  end

  def diskSig
    @dInfo.diskSig ||= getDiskSig
  end

  def getPartitions
    discoverPartitions
  end

  def seekPos
    @seekPos - @startByteAddr
  end

  def seek(amt, whence = IO::SEEK_SET)
    case whence
    when IO::SEEK_CUR
      @seekPos += amt
    when IO::SEEK_END
      @seekPos = @endByteAddr + amt
    when IO::SEEK_SET
      @seekPos = amt + @startByteAddr
    end
    @seekPos
  end

  def read(len)
    rb = d_read(@seekPos, len)
    @seekPos += rb.length unless rb.nil?
    (rb)
  end

  def write(buf, len)
    nbytes = d_write(@seekPos, buf, len)
    @seekPos += nbytes
    (nbytes)
  end

  def close
    $log.debug "MiqDisk<#{object_id}> close, #{@logName}" if $log
    @partitions.each(&:close) if @partitions
    @partitions = nil
    d_close
  end

  private

  MBR_SIZE = 512
  DOS_SIG  = "55aa"
  GPT_SIG  = 238   # 0xEE GPT Protective MBR
  DISK_SIG_OFFSET = 0x1B8
  DISK_SIG_SIZE = 4

  def getDiskSig
    sp = seekPos
    seek(DISK_SIG_OFFSET, IO::SEEK_SET)
    ds = read(DISK_SIG_SIZE).unpack('L')[0]
    seek(sp, IO::SEEK_SET)
    ds
  end

  DOS_PARTITION_ENTRY = BinaryStruct.new([
    'C', :bootable,
    'C', :startCHS0,
    'C', :startCHS1,
    'C', :startCHS2,
    'C', :ptype,
    'C', :endCHS0,
    'C', :endCHS1,
    'C', :endCHS1,
    'L', :startLBA,
    'L', :partSize
  ])
  PTE_LEN = DOS_PARTITION_ENTRY.size

  DOS_PT_START = 446
  DOS_NPTE = 4
  PTYPE_EXT_CHS = 0x05
  PTYPE_EXT_LBA = 0x0f
  PTYPE_LDM   = 0x42

  GPT_HEADER = BinaryStruct.new([
    'a8',    :signature, 	  # 00-07: Signature "EFI PART"
    'a4',    :version, 	 	  # 08-11: Revision
    'L',     :header_size, 	# 12-15: Header size
    'L',     :crc32_header, # 16-19: 
    'L',     :reserved, 	  # 20-23: 
    'Q',     :cur_lba, 		  # 24-31: 
    'Q',     :bak_lba, 		  # 32-39: 
    'Q',     :first_lba, 	  # 40-47: 
    'Q',     :last_lba, 	  # 48-55: 
    'a16',   :guid, 		    # 56-71: 
    'Q',     :startLBA, 	  # 72-79: 
    'L',     :partNum, 		  # 80-83: 
    'L',     :partSize, 	  # 84-87: 
    'L',     :part_array, 	# 88-91: 
    'a420',  :reserved2, 	  # 92-511: 
  ])

  GPT_PARTITION_ENTRY = BinaryStruct.new([
    'a16',   :ptype, 		  # 00-15: partition type
    'a16',   :pguid, 		  # 16-31: partition GUID
    'Q',     :firstLBA, 	# 32-39: first LBA
    'Q',     :lastLBA, 		# 40-47: last LBA
    'a8',    :attr_flag, 	# 48-55: attribute flag
    'a72',   :pname, 		  # 56-127: partition name
  ])

  def discoverPartitions
    return @partitions unless @partitions.nil?

    $log.debug "MiqDisk<#{object_id}> discoverPartitions, disk file: #{@dInfo.fileName}" if $log
    seek(0, IO::SEEK_SET)
    mbr = read(MBR_SIZE)

    if mbr.length < MBR_SIZE
      $log.info "MiqDisk<#{object_id}> discoverPartitions, disk file: #{@dInfo.fileName} does not contain a master boot record"
      return @partitions = []
    end

    sig = mbr[510..511].unpack('H4')

    ptEntry = DOS_PARTITION_ENTRY.decode(mbr[DOS_PT_START, PTE_LEN])
    ptype = ptEntry[:ptype]

    return(discoverDosGptPartitions) if ptype == GPT_SIG && sig[0] == DOS_SIG
    return(discoverDosPriPartitions(mbr)) if sig[0] == DOS_SIG
    @partitions = []
  end

  def discoverDosGptPartitions
    $log.info "Parsing GPT disk ..."
    seek(MBR_SIZE, IO::SEEK_SET)
    gpt_header = read(GPT_HEADER.size)
    header = GPT_HEADER.decode(gpt_header)

    $log.debug "header = #{header}"
    @partitions = []
    pte = GPT_HEADER.size + MBR_SIZE
    (1..header[:partNum]).each do |n|
      seek(pte, IO::SEEK_SET)
      gpt = read(GPT_PARTITION_ENTRY.size)
      ptEntry = GPT_PARTITION_ENTRY.decode(gpt)
      ptype = ptEntry[:ptype]

      @partitions.push(MiqPartition.new(self, ptype, ptEntry[:firstLBA], ptEntry[:lastLBA], n)) if ptEntry[:firstLBA] != 0
      pte += header[:partSize]
    end
    (@partitions)
  end

  def discoverDosPriPartitions(mbr)
    pte = DOS_PT_START
    @partitions = []
    (1..DOS_NPTE).each do |n|
      ptEntry = DOS_PARTITION_ENTRY.decode(mbr[pte, PTE_LEN])
      pte += PTE_LEN
      ptype = ptEntry[:ptype]

      #
      # If this os an LDM (dynamic) disk, then ignore any partitions.
      #
      if ptype == PTYPE_LDM
        $log.debug "MiqDisk::discoverDosPriPartitions: detected LDM (dynamic) disk"
        @partType = PTYPE_LDM
        return([])
      end

      if ptype == PTYPE_EXT_CHS || ptype == PTYPE_EXT_LBA
        @partitions.concat(discoverDosExtPartitions(ptEntry[:startLBA], ptEntry[:startLBA], DOS_NPTE + 1))
        next
      end
      @partitions.push(MiqPartition.new(self, ptype, ptEntry[:startLBA], ptEntry[:partSize], n)) if ptype != 0
    end
    (@partitions)
  end

  #
  # Discover secondary file system partitions within a primary extended partition.
  #
  # priBaseLBA is the LBA of the primary extended partition.
  #     All pointers to secondary extended partitions are relative to this base.
  #
  # ptBaseLBA is the LBA of the partition table within the current extended partition.
  #     All pointers to secondary file system partitions are relative to this base.
  #
  def discoverDosExtPartitions(priBaseLBA, ptBaseLBA, pNum)
    ra = []
    seek(ptBaseLBA * @blockSize, IO::SEEK_SET)
    mbr = read(MBR_SIZE)

    #
    # Create and add disk object for secondary file system partition.
    # NOTE: the start of the partition is relative to ptBaseLBA.
    #
    pte = DOS_PT_START
    ptEntry = DOS_PARTITION_ENTRY.decode(mbr[pte, PTE_LEN])
    ra << MiqPartition.new(self, ptEntry[:ptype], ptEntry[:startLBA] + ptBaseLBA, ptEntry[:partSize], pNum) if ptEntry[:ptype] != 0

    #
    # Follow the chain to the next secondary extended partition.
    # NOTE: the start of the partition is relative to priBaseLBA.
    #
    pte += PTE_LEN
    ptEntry = DOS_PARTITION_ENTRY.decode(mbr[pte, PTE_LEN])
    ra.concat(discoverDosExtPartitions(priBaseLBA, ptEntry[:startLBA] + priBaseLBA, pNum + 1)) if ptEntry[:startLBA] != 0

    ra
  end
end

class MiqPartition < MiqDisk
  def initialize(baseDisk, pType, lbaStart, lbaEnd, partNum)
    @baseDisk = baseDisk
    $log.debug "MiqPartition<#{object_id}> initialize partition for: #{@baseDisk.dInfo.fileName}" if $log
    super(nil, baseDisk.dInfo.clone, pType, lbaStart, lbaEnd, partNum)
  end

  def d_init
    $log.debug "MiqPartition<#{object_id}> d_init called"
    @blockSize = @baseDisk.blockSize
  end

  def d_read(pos, len)
    @baseDisk.d_read(pos, len)
  end

  def d_write(pos, buf, len)
    @baseDisk.d_write(pos, buf, len)
  end

  def d_size
    raise "MiqPartition: d_size should not be called for partition"
  end

  def d_close
  end
end
