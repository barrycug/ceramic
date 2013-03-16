module Ceramic
  module Builder

    class TilesetBuilder
      
      SOURCE_BUILDER_TYPES = {
        :proc => ProcSourceBuilder,
        :postgis => PostGISSourceBuilder,
      }
  
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

      # Specify the tileset's scale.
      # @param [Integer] value
      # @see Ceramic::Tileset#scale
      def scale(value)
        @tileset.scale = value
      end

      # Specify the tileset's margin.
      # @param [Float] value
      # @see Ceramic::Tileset#margin
      def margin(value)
        @tileset.margin = value
      end
      
      # Specify the tileset's coordinate system.
      # @param [:tile, :latlon] value
      # @see Ceramic::Tileset#coordinates
      def coordinates(value)
        unless [:tile, :latlon].include?(value)
          raise ArgumentError, "Unknown coordinate system #{value.inspect}"
        end
        
        @tileset.coordinates = value
      end

      # Add a source to the tileset's list of sources.
      # @param [Class, Symbol] type
      # @see Ceramic::Tileset#sources
      def source(type, options = {}, &block)
        source = if type.is_a?(Class)
          type.new(options)
        elsif type.is_a?(Symbol)
          unless SOURCE_BUILDER_TYPES.has_key?(type)
            raise ArgumentError, "Unknown source type #{type.inspect}"
          end
          SOURCE_BUILDER_TYPES[type].build(options, &block)
        else
          raise ArgumentError, "Sources must be specified as either a symbol (:postgis, :proc) or a source class"
        end
        
        @tileset.sources << source
      end

    end
    
  end
end
