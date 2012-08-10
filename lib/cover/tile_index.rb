require "global_map_tiles/global_map_tiles"

module Cover
  
  class TileIndex
    
    Bounds = Struct.new(:left, :top, :right, :bottom, :width, :height)

    attr_reader :z, :x, :y

    def initialize(*arguments)
      if arguments.size == 1 && String === arguments[0] && arguments[0] =~ /(\d+)\/(\d+)\/(\d+)/
        @z = $1.to_i
        @x = $2.to_i
        @y = $3.to_i
      elsif arguments.size == 3 && arguments.all? { |a| Integer === a }
        @z, @x, @y = *arguments
      else
        raise ArgumentError, "expected a z/x/y path string or three integers"
      end
    end
    
    def to_s
      "#{z}/#{x}/#{y}"
    end

    def bounds
      unless instance_variable_defined?(:@bounds)
        mercator = GlobalMercator.new
        tile_bounds = mercator.tile_bounds(*mercator.google_tile(x, y, z), z)
      
        @bounds = Bounds.new(tile_bounds[0], tile_bounds[3], tile_bounds[2], tile_bounds[1], tile_bounds[2] - tile_bounds[0], tile_bounds[3] - tile_bounds[1])
      end
      
      @bounds
    end

  end
    
end
