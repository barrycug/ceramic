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
    
    def self.load_config(path)
      unless File.exist?(path)
        raise ArgumentError, "Configuration file not found: #{path}"
      end
      
      Cover.config = nil
      require File.expand_path(path)
      
      unless Cover.config != nil
        raise ArgumentError, "Configuration file did not assign Cover.config"
      end
      
      unless Cover.config.respond_to?(:maker)
        raise ArgumentError, "Object assigned to Cover.config does not respond to #maker"
      end
      
      Cover.config
    end
    
    def self.load_tile_indices(strings)
      
      strings.inject([]) do |indices, string|
        if File.exist?(string)
          File.open(string, "r").each_line do |line|
            next if line =~ /^#/ || line =~ /^\s*$/
            indices << Cover::TileIndex.new(line)
          end
        else
          indices << Cover::TileIndex.new(string)
        end
        indices
      end
      
    end
  
  end
  
end
