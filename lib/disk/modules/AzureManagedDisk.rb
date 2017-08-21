require_relative "../MiqDisk"
require 'ostruct'

module AzureManagedDisk
  # The maximum read length that supports MD5 return.
  MAX_READ_LEN = 1024 * 1024 * 4

  def self.new(svc, disk_name, dInfo = nil)
    d_info = dInfo || OpenStruct.new
    d_info.storage_disk_svc = svc
    d_info.disk_name        = disk_name
    d_info.fileName         = disk_name

    MiqDisk.new(self, d_info, 0)
  end

  def d_init
    @diskType         = "azure-managed"
    @blockSize        = 512
    @disk_name        = @dInfo.disk_name
    @storage_disk_svc = @dInfo.storage_disk_svc
    @resource_group   = @dInfo.resource_group

    $log.debug "AzureManagedDisk: open(#{@disk_name})"
    @t0 = Time.now.to_i
    @reads = 0
    @bytes = 0
    @split_reads = 0
  end

  def d_close
    return nil unless $log.debug?
    t1 = Time.now.to_i
    $log.debug "AzureManagedDisk: close(#{@disk_name})"
    $log.debug "AzureManagedDisk: (#{@disk_name}) time:  #{t1 - @t0}"
    $log.debug "AzureManagedDisk: (#{@disk_name}) reads: #{@reads}, split_reads: #{@split_reads}"
    $log.debug "AzureManagedDisk: (#{@disk_name}) bytes: #{@bytes}"
    nil
  end

  def d_read(pos, len)
    $log.debug "AzureManagedDisk#d_read(#{pos}, #{len})"
    return blob_read(pos, len) unless len > MAX_READ_LEN

    @split_reads += 1
    ret = ""
    blocks, rem = len.divmod(MAX_READ_LEN)

    blocks.times do
      ret << blob_read(pos, MAX_READ_LEN)
    end
    ret << blob_read(pos, rem) if rem > 0

    ret
  end

  def d_size
    @d_size ||= blob_headers[:content_range].split("/")[1].to_i
  end

  def d_write(_pos, _buf, _len)
    raise "Write operation not supported."
  end

  private

  def blob_read(start_byte, length)
    $log.debug "AzureManagedDisk#blob_read(#{start_byte}, #{length})"
    options = {
      :start_byte => start_byte,
      :length     => length
    }
    # options[:date] = @snapshot if @snapshot

    ret = @storage_disk_svc.get_blob_raw(@disk_name, @resource_group, options)
    $log.debug "AzureManagedDisk#blob_read read #{disk_name} and returned #{ret.body.length} bytes)"

    @reads += 1
    @bytes += ret.body.length

    ret.body
  end

  def blob_headers
    $log.debug "AzureManagedDisk#blob_headers"
    @blob_headers ||= begin
      options = {
        :start_byte => 0,
        :length     => 1
      }
      data = @storage_disk_svc.get_blob_raw(@disk_name, @resource_group, options)
      data.headers
    end
  end
end
