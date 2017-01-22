require 'fs/MiqFS/modules/WebDAV'

class MiqContainerGroup
  attr_reader :uri, :http_options, :headers, :guest_os

  # http_options are in Net::HTTP format.
  def initialize(uri, http_options, headers, guest_os)
    @uri = uri
    unless http_options.kind_of?(Hash)
      # backward compatibility, 2nd param used to be verify_mode
      http_options = {:verify_mode => http_options}
    end
    @http_options = {:use_ssl => URI(uri).scheme == 'https'}.merge(http_options)
    @headers      = headers
    @guest_os     = guest_os
  end

  def verify_mode
    http_options[:verify_mode]
  end

  def rootTrees
    web_dav_ost = OpenStruct.new(
      :uri          => @uri,
      :http_options => @http_options,
      :headers      => @headers,
      :guest_os     => @guest_os
    )
    [MiqFS.new(WebDAV, web_dav_ost)]
  end
end
