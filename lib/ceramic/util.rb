module Ceramic
  
  module Util
    
    # @param [String, Integer, Range] zoom_specifier A string, integer, or range specifying an integral zoom range.
    # @return [Range<Integer>]
  
    def self.parse_zoom(zoom_specifier)
      if String === zoom_specifier
        if zoom_specifier =~ /(\d+)?-(\d+)?/
          Range.new($1.nil? ? 0 : $1.to_i, $2.nil? ? 1.0/0 : $2.to_i)
        elsif zoom_specifier =~ /(\d+)/
          Range.new($1.to_i, $1.to_i)
        else
          raise ArgumentError, "invalid zoom specifier"
        end
      elsif Integer === zoom_specifier
        Range.new(zoom_specifier, zoom_specifier)
      elsif Range === zoom_specifier
        zoom_specifier
      else
        raise ArgumentError, "invalid zoom specifier"
      end
    end
  
  end
  
end
