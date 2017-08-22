require_relative "../MiqDisk"
require 'ostruct'

module AzureBlobDisk
  # The maximum read length that supports MD5 return.
  MAX_READ_LEN = 1024 * 1024 * 4

  def self.new(svc, blob_uri, dInfo = nil)
    d_info = dInfo || OpenStruct.new
    d_info.storage_acct_svc = svc
    d_info.blob_uri         = blob_uri
    d_info.fileName         = blob_uri

    MiqDisk.new(self, d_info, 0)
  end

  def d_init
    @diskType         = "azure-blob"
    @blockSize        = AzureCommon::SECTOR_LENGTH
    @blob_uri         = @dInfo.blob_uri
    @storage_acct_svc = @dInfo.storage_acct_svc
    AzureCommon.d_init_common(@dInfo)
  end

  def d_close
    AzureCommon.d_close_common
  end

  def d_read(pos, len)
    $log.debug "AzureBlobDisk#d_read(#{pos}, #{len})"
    AzureCommon.d_read_common(pos, len)
  end

  def d_size
    @d_size ||= AzureCommon.blob_properties[:content_length].to_i
  end

  def d_write(_pos, _buf, _len)
    raise "Write operation not supported."
  end
end
