require "disk/modules/AzureDiskCommon"
require_relative "../MiqDisk"
require 'ostruct'

module AzureManagedDisk
  include AzureDiskCommon
  def self.new(svc, disk_name, dInfo = nil)
    d_info = dInfo || OpenStruct.new
    d_info.storage_disk_svc = svc
    d_info.disk_name        = disk_name
    d_info.fileName         = disk_name

    MiqDisk.new(self, d_info, 0)
  end

  def d_init
    @diskType         = "azure-managed"
    @blockSize        = SECTOR_LENGTH
    @disk_name        = @dInfo.disk_name
    @storage_disk_svc = @dInfo.storage_disk_svc
    @resource_group   = @dInfo.resource_group
    d_init_common(@dInfo)
  end

  def d_close
    d_close_common
  end

  def d_read(pos, len)
    $log.debug("AzureManagedDisk#d_read(#{pos}, #{len})")
    d_read_common(pos, len)
  end

  def d_size
    @d_size ||= blob_headers[:content_range].split("/")[1].to_i
  end

  def d_write(_pos, _buf, _len)
    raise "Write operation not supported."
  end

  private

  def blob_headers
    $log.debug("AzureManagedDisk#blob_headers")
    @blob_headers ||= begin
      options = {
        :start_byte => 0,
        :length     => 1
      }
      data = managed_disk.read(options)
      data.headers
    end
  end
end
