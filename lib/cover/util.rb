module Cover
  
  module Util
  
    def self.parse_zoom(zoom)
      if String === zoom
        if zoom =~ /(\d+)?-(\d+)?/
          Range.new($1.nil? ? 0 : $1.to_i, $2.nil? ? 1.0/0 : $2.to_i)
        elsif zoom =~ /(\d+)/
          Range.new($1.to_i, $1.to_i)
        else
          raise ArgumentError, "invalid zoom specifier"
        end
      elsif Integer === zoom
        Range.new(zoom, zoom)
      elsif Range === zoom
        zoom
      else
        raise ArgumentError, "invalid zoom specifier"
      end
    end
  
  end
  
end
