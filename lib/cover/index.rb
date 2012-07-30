require "global_map_tiles/global_map_tiles"

module Cover
  
  class Index
    
    def self.from_string(string)
      if string =~ /(\d+)\/(\d+)\/(\d+)/
        self.new($1.to_i, $2.to_i, $3.to_i)
      else
        raise ArgumentError.new("#{string} is not a valid index string")
      end
    end
  
    attr_reader :z, :x, :y
  
    def initialize(z, x, y)
    
      @z, @x, @y = z, x, y
    
      mercator = GlobalMercator.new
      @bounds = mercator.tile_bounds(*mercator.google_tile(@x, @y, @z), @z)
    
    end
    
    def to_s
      "#{z}/#{x}/#{y}"
    end
  
    def bbox(srid)
    
      if srid != 900913 && srid != 3857
        raise ArgumentError, "Only SRIDs 900913 and 3857 are supported"
      end
    
      {
        left: @bounds[0],
        top: @bounds[3],
        right: @bounds[2],
        bottom: @bounds[1],
        width: @bounds[2] - @bounds[0],
        height: @bounds[3] - @bounds[1]
      }
    
    end
    
  end
  
end
