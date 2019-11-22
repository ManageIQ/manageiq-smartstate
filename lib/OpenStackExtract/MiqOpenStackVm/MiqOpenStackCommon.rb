module MiqOpenStackCommon
  def disk_format_glance_v1(snapshot_image_id)
    image_service.get_image(snapshot_image_id).headers['X-Image-Meta-Disk_format']
  end

  def disk_format_glance_v2(snapshot_image_id)
    image_service.images.get(snapshot_image_id).disk_format
  end

  def disk_format(snapshot_image_id)
    send("disk_format_glance_#{image_service.version}", snapshot_image_id)
  end

  def get_image_metadata_snapshot_id(image)
    image.metadata.each do |m|
      next if m.key != "block_device_mapping"
      return m.value[0]['snapshot_id']
    end 
  end

  def download_image_data_glance_v2(image)
    log_prefix = "#{self.class.name}##{__method__}"

    image_id = image.id
    iname = image.name
    isize = image.size.to_i
    $log.debug "#{log_prefix}: iname = #{iname}"
    $log.debug "#{log_prefix}: isize = #{isize}"

    raise "Image: #{iname} (#{image_id}) is empty" unless isize > 0
    tot = 0
    tf = MiqTempfile.new(iname, :encoding => 'ascii-8bit')
    $log.debug "#{log_prefix}: saving image to #{tf.path}"
    response_block = lambda do |buf, _rem, sz|
      tf.write buf
      tot += buf.length
      $log.debug "#{log_prefix}: response_block: #{tot} bytes written of #{sz}"
    end

    _rv = image.download_data(:response_block => response_block)
    tf.close

    # TODO(lsmola) Fog download_data doesn't support header returned, it returns body by hard. We need to wrap the
    # result load_response like in Fog::OpenStack::Collection. The header will be accessible as rv.response.headers
    # checksum = rv.headers['Content-Md5']
    # $log.debug "#{log_prefix}: Checksum: #{checksum}" if $log.debug?
    $log.debug "#{log_prefix}: #{`ls -l #{tf.path}`}" if $log.debug?

    if tf.size != isize
      $log.error "#{log_prefix}: Error downloading image #{iname}"
      $log.error "#{log_prefix}: Downloaded size does not match image size #{tf.size} != #{isize}"
      raise "Image download failed"
    end
    tf
  end
  
  def create_image_from_snapshot(snapshot_id, disk_format)
    snapshot = volume_service.snapshots.get(snapshot_id)
    volume_options = {
      :name        => "Temp Volume from #{snapshot.name}",
      :size        => snapshot.size,
      :snapshot_id => snapshot_id
    }
    volume = volume_service.volumes.new(volume_options)
    volume.save

    while volume.status != 'available'
      sleep(10)
      volume = volume_service.volumes.get(volume.id)
    end

    response = volume_service.action(volume.id, 'os-volume_upload_image' => {
                                       :image_name => "Temp Image from #{snapshot.name}",
                                       :disk_format => disk_format})
    image_id = response.body["os-volume_upload_image"]["image_id"]

    while image_service.images.get(image_id).status.downcase != 'active'
      sleep(10)
    end

    $log.debug "#{log_prefix}: Deleting temp volume #{volume.name} in #{volume.status} status"
    volume.destroy

    return image_service.images.get(image_id)
  rescue => ex
    $log.error "#{log_prefix}: Create image from Snapshot step raised error"
    $log.error ex
  end
  
  def get_image_file_glance_v2(image_id)
    log_prefix = "#{self.class.name}##{__method__}"

    image = image_service.images.get(image_id)
    raise "Image #{image_id} not found" unless image
    $log.debug "#{log_prefix}: image = #{image.class.name}"

    if image.size.to_i == 0
      # try getting image from metadata; oddly the image metadata is only available if
      # image is queried through compute service
      unless (snapshot_id = get_image_metadata_snapshot_id(compute_service.images.get(image_id))).nil?
        temp_image = create_image_from_snapshot(snapshot_id, image.disk_format)
        begin
          tf = download_image_data_glance_v2(temp_image)
        ensure
          temp_image.destroy
        end
      end
    else
      tf = download_image_data_glance_v2(image)
    end
    tf
  end

  def get_image_file_glance_v1(image_id)
    log_prefix = "#{self.class.name}##{__method__}"

    image = image_service.get_image(image_id)
    raise "Image #{image_id} not found" unless image
    $log.debug "#{log_prefix}: image = #{image.class.name}"

    iname = image.headers['X-Image-Meta-Name']
    isize = image.headers['X-Image-Meta-Size'].to_i
    $log.debug "#{log_prefix}: iname = #{iname}"
    $log.debug "#{log_prefix}: isize = #{isize}"

    raise "Image: #{iname} (#{image_id}) is empty" unless isize > 0

    tot = 0
    tf = MiqTempfile.new(iname, :encoding => 'ascii-8bit')
    $log.debug "#{log_prefix}: saving image to #{tf.path}"
    response_block = lambda do |buf, _rem, sz|
      tf.write buf
      tot += buf.length
      $log.debug "#{log_prefix}: response_block: #{tot} bytes written of #{sz}"
    end

    #
    # We're calling the low-level request method here, because
    # the Fog "get image" methods don't currently support passing
    # a response block. We should attempt to remedy this in Fog
    # upstream and modify this code accordingly.
    #
    rv = image_service.request(
      :expects        => [200, 204],
      :method         => 'GET',
      :path           => "images/#{image_id}",
      :response_block => response_block
    )

    tf.close

    checksum = rv.headers['X-Image-Meta-Checksum']
    $log.debug "#{log_prefix}: Checksum: #{checksum}" if $log.debug?
    $log.debug "#{log_prefix}: #{`ls -l #{tf.path}`}" if $log.debug?

    if tf.size != isize
      $log.error "#{log_prefix}: Error downloading image #{iname}"
      $log.error "#{log_prefix}: Downloaded size does not match image size #{tf.size} != #{isize}"
      raise "Image download failed"
    end
    tf
  end

  def get_image_file_common(image_id)
    send("get_image_file_glance_#{image_service.version}", image_id)
  end
end
