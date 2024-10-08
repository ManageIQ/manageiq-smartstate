# encoding: US-ASCII

require 'fs/ext4/group_descriptor_table'
require 'fs/ext4/inode'

require 'binary_struct'
require 'uuidtools'
require 'stringio'
require 'memory_buffer'

require 'rufus/lru'

module Ext4
  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions. Linux 2.6.2 from Fedora Core 6.

  SUPERBLOCK = BinaryStruct.new([
    'L',  'num_inodes',         # Number of inodes in file system.
    'L',  'num_blocks',         # Number of blocks in file system.
    'L',  'reserved_blocks',    # Number of reserved blocks to prevent file system from filling up.
    'L',  'unallocated_blocks', # Number of unallocated blocks.
    'L',  'unallocated_inodes', # Number of unallocated inodes.
    'L',  'block_group_zero',   # Block where block group 0 starts.
    'L',  'block_size',         # Block size (saved as num bits to shift 1024 left).
    'L',  'fragment_size',      # Fragment size (saved as num bits to shift 1024 left).
    'L',  'blocks_in_group',    # Number of blocks in each block group.
    'L',  'fragments_in_group', # Number of fragments in each block group.
    'L',  'inodes_in_group',    # Number of inodes in each block group.
    'L',  'last_mount_time',    # Time FS was last mounted.
    'L',  'last_write_time',    # Time FS was last written to.
    'S',  'mount_count',        # Current mount count.
    'S',  'max_mount_count',    # Maximum mount count.
    'S',  'signature',          # Always 0xef53
    'S',  'fs_state',           # File System State: see FSS_ below.
    'S',  'err_method',         # Error Handling Method: see EHM_ below.
    'S',  'ver_minor',          # Minor version number.
    'L',  'last_check_time',    # Last consistency check time.
    'L',  'forced_check_int',   # Forced check interval.
    'L',  'creator_os',         # Creator OS: see CO_ below.
    'L',  'ver_major',          # Major version: see MV_ below.
    'S',  'uid_res_blocks',     # UID that can use reserved blocks.
    'S',  'gid_res_blocks',     # GID that can uss reserved blocks.
    # Begin dynamic version fields
    'L',  'first_inode',        # First non-reserved inode in file system.
    'S',  'inode_size',         # Size of each inode.
    'S',  'block_group',        # Block group that this superblock is part of (if backup copy).
    'L',  'compat_flags',       # Compatible feature flags (see CFF_ below).
    'L',  'incompat_flags',     # Incompatible feature flags (see ICF_ below).
    'L',  'ro_flags',           # Read Only feature flags (see ROF_ below).
    'a16',  'fs_id',            # File system ID (UUID or GUID).
    'a16',  'vol_name',         # Volume name.
    'a64',  'last_mnt_path',    # Path where last mounted.
    'L',  'algo_use_bmp',       # Algorithm usage bitmap.
    # Performance hints
    'C',  'file_prealloc_blks', # Blocks to preallocate for files.
    'C',  'dir_prealloc_blks',  # Blocks to preallocate for directories.
    'S',  'unused1',            # Unused.
    # Journal support
    'a16',  'jrnl_id',          # Joural ID (UUID or GUID).
    'L',  'jrnl_inode',         # Journal inode.
    'L',  'jrnl_device',        # Journal device.
    'L',  'orphan_head',        # Head of orphan inode list.
    'a16',  'hash_seed',        # HTREE hash seed. This is actually L4 (__u32 s_hash_seed[4])
    'C',  'hash_ver',           # Default hash version.
    'C',  'unused2',
    'S',  'group_desc_size',    # Group descriptor size.
    'L',  'mount_opts',         # Default mount options.
    'L',  'first_meta_blk_grp', # First metablock block group.
    'a360', 'reserved'          # Unused.
  ])

  SUPERBLOCK_SIG = 0xef53
  SUPERBLOCK_OFFSET = 1024
  SUPERBLOCK_SIZE = 1024
  GDE_SIZE = 32  		            # default group descriptor size.
  INODE_SIZE = 128              # Default inode size.

  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class Superblock
    # Default cache sizes.
    DEF_BLOCK_CACHE_SIZE = 50
    DEF_INODE_CACHE_SIZE = 50

    # File System State.
    FSS_CLEAN       = 0x0001  # File system is clean.
    FSS_ERR         = 0x0002  # File system has errors.
    FSS_ORPHAN_REC  = 0x0004  # Orphan inodes are being recovered.
    # NOTE: Recovered NOT by this software but by the 'NIX kernel.
    # IOW start the VM to repair it.
    FSS_END         = FSS_CLEAN | FSS_ERR | FSS_ORPHAN_REC

    # Error Handling Method.
    EHM_CONTINUE    = 1 # No action.
    EHM_RO_REMOUNT  = 2 # Remount file system as read only.
    EHM_PANIC       = 3 # Don't mount? halt? - don't know what this means.

    # Creator OS.
    CO_LINUX    = 0 # NOTE: FS creation tools allow setting this value.
    CO_GNU_HURD = 1 # These values are supposedly defined.
    CO_MASIX    = 2
    CO_FREE_BSD = 3
    CO_LITES    = 4

    # Major Version.
    MV_ORIGINAL = 0 # NOTE: If version is not dynamic, then values from
    MV_DYNAMIC  = 1 # first_inode on may not be accurate.

    # Compatible Feature Flags.
    CFF_PREALLOC_DIR_BLKS = 0x0001  # Preallocate directory blocks to reduce fragmentation.
    CFF_AFS_SERVER_INODES = 0x0002  # AFS server inodes exist in system.
    CFF_JOURNAL           = 0x0004  # File system has journal (Ext3).
    CFF_EXTENDED_ATTRIBS  = 0x0008  # Inodes have extended attributes.
    CFF_BIG_PART          = 0x0010  # File system can resize itself for larger partitions.
    CFF_HASH_INDEX        = 0x0020  # Directories use hash index (another modified b-tree).
    CFF_FLAGS             = (CFF_PREALLOC_DIR_BLKS | CFF_AFS_SERVER_INODES | CFF_JOURNAL | CFF_EXTENDED_ATTRIBS | CFF_BIG_PART | CFF_HASH_INDEX)

    # Incompatible Feature flags.
    ICF_COMPRESSION       = 0x0001  # Not supported on Linux?
    ICF_FILE_TYPE         = 0x0002  # Directory entries contain file type field.
    ICF_RECOVER_FS        = 0x0004  # File system needs recovery.
    ICF_JOURNAL           = 0x0008  # File system uses journal device.
    ICF_META_BG           = 0x0010  #
    ICF_EXTENTS           = 0x0040  # File system uses extents (ext4)
    ICF_64BIT             = 0x0080  # File system uses 64-bit
    ICF_MMP               = 0x0100  #
    ICF_FLEX_BG           = 0x0200  #
    ICF_EA_INODE          = 0x0400  # EA in inode
    ICF_DIRDATA           = 0x1000  # data in dirent
    ICF_FLAGS             = (ICF_COMPRESSION | ICF_FILE_TYPE | ICF_RECOVER_FS | ICF_JOURNAL | ICF_META_BG | ICF_EXTENTS | ICF_64BIT | ICF_MMP | ICF_FLEX_BG | ICF_EA_INODE | ICF_DIRDATA)

    # ReadOnly Feature flags.
    ROF_SPARSE            = 0x0001  # Sparse superblocks & group descriptor tables.
    ROF_LARGE_FILES       = 0x0002  # File system contains large files (over 4G).
    ROF_BTREES            = 0x0004  # Directories use B-Trees (not implemented?).
    ROF_HUGE_FILE         = 0x0008  #
    ROF_GDT_CSUM          = 0x0010  #
    ROF_DIR_NLINK         = 0x0020  #
    ROF_EXTRA_ISIZE       = 0x0040  #
    ROF_FLAGS             = (ROF_SPARSE | ROF_LARGE_FILES | ROF_BTREES | ROF_HUGE_FILE | ROF_GDT_CSUM | ROF_DIR_NLINK | ROF_EXTRA_ISIZE)

    # /////////////////////////////////////////////////////////////////////////
    # // initialize
    attr_reader :numGroups, :fsId, :stream, :numBlocks, :numInodes, :volName
    attr_reader :sectorSize, :blockSize

    @@track_inodes = false

    def initialize(stream)
      raise "Ext4::Superblock.initialize: Nil stream" if (@stream = stream).nil?

      # Seek, read & decode the superblock structure
      @stream.seek(SUPERBLOCK_OFFSET)
      @sb = SUPERBLOCK.decode(@stream.read(SUPERBLOCK_SIZE))

      # Grab some quick facts & make sure there's nothing wrong. Tight qualification.
      raise "Ext4::Superblock.initialize: Invalid signature=[#{@sb['signature']}]" if @sb['signature'] != SUPERBLOCK_SIG
      raise "Ext4::Superblock.initialize: Invalid file system state" if @sb['fs_state'] > FSS_END
      if (state = @sb['fs_state']) != FSS_CLEAN
        $log.warn("Ext4 file system has errors")        if $log && gotBit?(state, FSS_ERR)
        $log.warn("Ext4 orphan inodes being recovered") if $log && gotBit?(state, FSS_ORPHAN_REC)
      end
      raise "Ext4::Superblock.initialize: Invalid error handling method=[#{@sb['err_method']}]" if @sb['err_method'] > EHM_PANIC

      @blockSize = 1024 << @sb['block_size']

      @block_cache = LruHash.new(DEF_BLOCK_CACHE_SIZE)
      @inode_cache = LruHash.new(DEF_INODE_CACHE_SIZE)

      # expose for testing.
      @numBlocks = @sb['num_blocks']
      @numInodes = @sb['num_inodes']

      # Inode file size members can't be trusted, so use sector count instead.
      # MiqDisk exposes blockSize, which for our purposes is sectorSize.
      @sectorSize = @stream.blockSize

      # Preprocess some members.
      @sb['vol_name'].delete!("\000")
      @sb['last_mnt_path'].delete!("\000")
      @numGroups, @lastGroupBlocks = @sb['num_blocks'].divmod(@sb['blocks_in_group'])
      @numGroups += 1 if @lastGroupBlocks > 0
      @fsId = UUIDTools::UUID.parse_raw(@sb['fs_id'])
      @volName = @sb['vol_name']
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Class helpers & accessors.

    def gdt
      @gdt ||= GroupDescriptorTable.new(self)
    end

    def isDynamic?
      @sb['ver_major'] == MV_DYNAMIC
    end

    def isNewDirEnt?
      gotBit?(@sb['incompat_flags'], ICF_FILE_TYPE)
    end

    def fragmentSize
      1024 << @sb['fragment_size']
    end

    def blocksPerGroup
      @sb['blocks_in_group']
    end

    def fragmentsPerGroup
      @sb['fragments_in_group']
    end

    def inodesPerGroup
      @sb['inodes_in_group']
    end

    def inodeSize
      isDynamic? ? @sb['inode_size'] : INODE_SIZE
    end

    def is_enabled_64_bit?
      @is_enabled_64_bit ||= gotBit?(@sb['incompat_flags'], ICF_64BIT)
    end

    def groupDescriptorSize
      @groupDescriptorSize ||= is_enabled_64_bit? ? @sb['group_desc_size'] : GDE_SIZE
    end

    def freeBytes
      @sb['unallocated_blocks'] * @blockSize
    end

    def blockNumToGroupNum(block)
      unless block.kind_of?(Numeric)
        $log.error("Ext4::Superblock.blockNumToGroupNum called from: #{caller.join('\n')}")
        raise "Ext4::Superblock.blockNumToGroupNum: block is expected to be numeric, but is <#{block.class.name}>"
      end
      group = (block - @sb['block_group_zero']) / @sb['blocks_in_group']
      offset = block.modulo(@sb['blocks_in_group'])
      return group, offset
    end

    def firstGroupBlockNum(group)
      group * @sb['blocks_in_group'] + @sb['block_group_zero']
    end

    def inodeNumToGroupNum(inode)
      (inode - 1).divmod(inodesPerGroup)
    end

    def blockToAddress(block)
      address  = block * @blockSize
      address += (SUPERBLOCK_SIZE + groupDescriptorSize * @numGroups)  if address == SUPERBLOCK_OFFSET
      address
    end

    def isValidInode?(inode)
      group, offset = inodeNumToGroupNum(inode)
      gde = gdt[group]
      gde.inodeAllocBmp[offset]
    end

    def isValidBlock?(block)
      group, offset = blockNumToGroupNum(block)
      gde = gdt[group]
      gde.blockAllocBmp[offset]
    end

    # Ignore allocation is for testing only.
    def getInode(inode, _ignore_alloc = false)
      unless @inode_cache.key?(inode)
        group, offset = inodeNumToGroupNum(inode)
        gde = gdt[group]
        # raise "Inode #{inode} is not allocated" if (not gde.inodeAllocBmp[offset] and not ignore_alloc)
        @stream.seek(blockToAddress(gde.inodeTable) + offset * inodeSize)
        @inode_cache[inode] = Inode.new(@stream.read(inodeSize), self, inode)
        $log.info "Inode num: #{inode}\n#{@inode_cache[inode].dump}\n\n" if $log && @@track_inodes
      end

      @inode_cache[inode]
    end

    # Ignore allocation is for testing only.
    def getBlock(block, _ignore_alloc = false)
      raise "Ext4::Superblock.getBlock: block is nil" if block.nil?

      unless @block_cache.key?(block)
        if block == 0
          @block_cache[block] = MemoryBuffer.create(@blockSize)
        else
          # raise "Block #{block} is not allocated" if (not gde.blockAllocBmp[offset] and not ignore_alloc)

          address = blockToAddress(block)  # This function will read the block into our cache

          @stream.seek(address)
          @block_cache[block] = @stream.read(@blockSize)
        end
      end
      @block_cache[block]
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Utility functions.

    def gotBit?(field, bit)
      field & bit == bit
    end

    # Dump object.
  end
end # moule Ext4
