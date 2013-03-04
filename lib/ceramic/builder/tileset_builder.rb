module Ceramic
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
        source = if type.is_a?(Class)
          unless type.method_defined?(:query)
            raise ArgumentError, "Source classes must define #query"
          end
          type.new(options)
        elsif type.is_a?(Symbol)
          klass = case type
          when :proc
            ProcSourceBuilder
          when :postgis
            PostGISSourceBuilder
          when Symbol
            raise ArgumentError, "Unknown source type #{type.inspect}"
          end
          klass.build(options, &block)
        else
          raise ArgumentError, "Sources must be specified as either a symbol (:postgis, :proc) or a source class"
        end
        
        @tileset.sources << source
      end

    end
    
  end
end
