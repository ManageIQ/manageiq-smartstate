require 'uri'
require 'addressable'

module ManageIQ
  module Smartstate
    module Util
      def self.uri_to_local_path(uri_path)
        # Detect and return UNC paths
        return URI.decode(uri_path) if uri_path[0, 2] == '//'
        local = URI.decode(URI.parse(uri_path).path)
        return local[1..-1] if local[2, 1] == ':'
        return local
      rescue
        return uri_path
      end
    end
  end
end
