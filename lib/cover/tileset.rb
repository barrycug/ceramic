module Cover
  
  class Tileset
  
    class TilesetBuilder
    
      def initialize(options = {})
        @tileset = Tileset.new
      end
    
      def scale(value)
        @tileset.scale = value
      end
    
      def source(type, options = {}, &block)
        klass = case type
        when :proc
          Source::Proc
        else
          raise ArgumentError, "Unknown source type #{type.inspect}"
        end
      
        @tileset.sources << klass.build(options, &block)
      end
    
    end
  
    class << self
    
      def build(options = {}, &block)
        builder = TilesetBuilder.new(options)
        builder.instance_exec(&block)
        builder.instance_variable_get(:@tileset)
      end
    
    end
  
    attr_accessor :sources
    attr_accessor :scale
    attr_accessor :writer
  
    def initialize
      @sources = []
      @scale = 1024
      @writer = Writer.new
    end
    
    def setup
      @sources.each do |source|
        source.setup if source.respond_to?(:setup)
      end
    end
    
    def teardown
      @sources.each do |source|
        source.teardown if source.respond_to?(:teardown)
      end
    end
  
    def write(index, io)
      io << "{"
      io << "\"scale\":#{scale},"
      io << "\"features\":["
    
      first = true
    
      sources.each do |source|
        
        source.query(index) do |feature|
          io << "," unless first
          writer.write(feature, io)
          first = false
        end
        
      end
    
      io << "]"
      io << "}"
    end
  
  end

end
