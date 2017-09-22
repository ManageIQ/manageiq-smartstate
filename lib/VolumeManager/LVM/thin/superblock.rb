module Lvm2Thin
  class SuperBlock
    attr_accessor :metadata_volume

    attr_accessor :struct

    def self.get(metadata_volume)
      @superblock ||= begin
        superblock = SuperBlock.new
        superblock.metadata_volume = metadata_volume
        superblock.seek 0
        superblock.struct = superblock.read_struct SUPERBLOCK
        raise "unknown lvm2 thin metadata magic number" if superblock.struct.magic != THIN_MAGIC
        superblock
      end
    end

    ### superblock properties:

    def md_block_size
      @md_block_size ||= struct['metadata_block_size'] * 512 # = 4096
    end

    def md_block_address(blk_addr)
      blk_addr * md_block_size
    end

    def entries_per_block
      @entries_per_block ||= (md_block_size - BITMAP_HEADER.size) * 4
    end

    def data_block_size
      @data_block_size ||= struct['data_block_size'] * 512
    end

    def data_block_address(blk_addr)
      blk_addr * data_block_size
    end

    ### lvm thin structures:

    def data_space_map
      @data_space_map ||= begin
        seek SUPERBLOCK.offset('data_space_map_root')
        DataSpaceMap.new self, read_struct(SPACE_MAP)
      end
    end

    def metadata_space_map
      @metadata_space_map ||= begin
        seek SUPERBLOCK.offset('metadata_space_map_root')
        MetadataSpaceMap.new self, read_struct(SPACE_MAP)
      end
    end

    def data_mapping_address
      @data_mapping_address ||= md_block_address(struct['data_mapping_root'])
    end

    def data_mapping
      @data_mapping ||= MappingTree.new self, data_mapping_address
    end

    def device_details_address
      @device_details_address ||= md_block_address(struct['device_details_root'])
    end

    def device_details
      @device_details ||= BTree.new self, device_details_address, DEVICE_DETAILS
    end

    ### address resolution / mapping:

    def device_block(device_address)
      (device_address / data_block_size).to_i
    end

    def device_block_offset(device_address)
      device_address % data_block_size
    end

    # Return array of tuples device block ids, data block ids, addresses, and lengths to
    # read from them to read the specified device offset & length.
    #
    # Note: data blocks may not amount to total requested length (if requesting
    # data from unallocated space).
    #
    # @see DataMap#block?
    def device_to_data(device_id, pos, len)
      dev_blk  = device_block(pos)
      dev_off  = device_block_offset(pos)
      data_map = data_mapping.map_for(device_id)

      total_len = 0
      data_blks = []

      num_data_blks = (len / data_block_size).to_i + 1
      0.upto(num_data_blks - 1) do |i|
        current_blk = dev_blk + i
        blk_len = 0

        if data_map.block?(current_blk)
          data_blk = data_map.data_block(current_blk)
          blk_start = data_blk * data_block_size

          if i.zero?
            blk_start += dev_off
            blk_len    = data_block_size - dev_off - 1

          elsif i == num_data_blks - 1
            blk_len = len - total_len

          else
            blk_len = data_block_size
          end

          data_blks << [current_blk, data_blk, blk_start, blk_len]

        # Missing block may be caused by trying to read beyond end of
        # LVM device (too large pos or len):
        else
          remaining  = (len - total_len)
          blk_len    = remaining > data_block_size ? data_block_size : remaining
          data_blks << [current_blk, nil, nil, blk_len]
        end

        total_len += blk_len
      end

      data_blks
    end

    ### metadata volume disk helpers:

    def seek(pos)
      @metadata_volume.disk.seek pos
    end

    def read(n)
      @metadata_volume.disk.read n
    end

    def read_struct(struct)
      OpenStruct.new(struct.decode(@metadata_volume.disk.read(struct.size)))
    end

    def read_structs(struct, num)
      Array.new(num) do
        read_struct struct
      end
    end
  end # class SuperBlock
end # module Lvm2Thin
