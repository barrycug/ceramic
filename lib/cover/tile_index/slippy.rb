require "global_map_tiles/global_map_tiles"

module Cover
  module TileIndex

    class Slippy

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
        mercator = GlobalMercator.new
        bounds = mercator.tile_bounds(*mercator.google_tile(x, y, z), z)
        
        Bounds.new(bounds[0], bounds[3], bounds[2], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1])
      end

    end
    
  end
end
