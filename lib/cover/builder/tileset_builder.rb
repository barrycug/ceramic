module Cover
  module Builder

    class TilesetBuilder
  
      class << self
        def build(options = {}, &block)
          builder = self.new(options)
          builder.instance_exec(&block)
          builder.instance_variable_get(:@tileset)
        end
      end
    
      def initialize(options = {})
        @tileset = Tileset.new
      end

      def scale(value)
        @tileset.scale = value
      end

      def margin(value)
        @tileset.margin = value
      end
      
      def coordinates(value)
        unless [:tile, :latlon].include?(value)
          raise ArgumentError, "Unknown coordinate system #{value.inspect}"
        end
        
        @tileset.coordinates = value
      end

      def source(type, options = {}, &block)
        klass = case type
        when :proc
          ProcSourceBuilder
        when :postgis
          PostGISSourceBuilder
        else
          raise ArgumentError, "Unknown source type #{type.inspect}"
        end
    
        @tileset.sources << klass.build(options, &block)
      end

    end
    
  end
end
