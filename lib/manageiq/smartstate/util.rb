require 'uri'
require 'util/MiqSockUtil'
require 'addressable'

module ManageIQ
  module Smartstate
    module Util
      def self.path_to_uri(file, hostname = nil)
        hostname ||= MiqSockUtil.getFullyQualifiedDomainName
        file = Addressable::URI.encode(file.tr('\\', '/'))

        begin
          URI::Generic.build(
            :scheme => 'file',
            :host   => hostname,
            :path   => "/#{file}"
          ).to_s
        rescue URI::InvalidComponentError # Punt on Windows volume names, etc
          "file://#{hostname}/#{file}"
        end
      end

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
