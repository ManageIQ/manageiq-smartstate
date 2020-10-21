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

      def self.base24_decode(byte_array)
        digits = %w(B C D F G H J K M P Q R T V W X Y 2 3 4 6 7 8 9)
        out = " " * 29
        out.length.downto(0) do |i|
          if i.modulo(6) == 0
            out[i, 1] = "-"
          else
            map_index = 0
            15.downto(0) do |j|
              byte_value = (map_index << 8) | byte_array[j]
              byte_array[j], map_index = byte_value.divmod(24)
              out[i, 1] = digits[map_index]
            end
          end
        end
        out[1..-1]
      end
    end
  end
end
