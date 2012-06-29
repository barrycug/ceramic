require "global_map_tiles/global_map_tiles"

module Cover
  
  class Index
    
    def self.bbox_list(bbox, levels)
      []
    end
    
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
    
    def left
      @bounds[0]
    end
    
    def right
      @bounds[2]
    end
    
    def top
      @bounds[3]
    end
    
    def bottom
      @bounds[1]
    end
    
    def width
      right - left
    end
    
    def height
      bottom - top
    end
    
  end
  
end
