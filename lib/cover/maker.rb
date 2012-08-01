require "json"
require "zlib"
require "stringio"

module Cover

  class Maker
  
    def initialize(options = {}, &block)
    
      if !block_given?
        raise ArgumentError, "A block must be given"
      end
      
      if !options.has_key?(:scale)
        raise ArgumentError, ":scale must be specified"
      end
    
      @scale = options[:scale]
      @block = block
    
    end
  
    class FeatureCollector
    
      def initialize(index, scale, size = 1)
        @index = index
        @scale = scale
        
        @list = Array.new(size * size) { [] }
        @size = size
      end
    
      def make(source, builder = nil)
        tiles = source.select_metatile(@index, @scale, @size)
        
        if builder
          tiles = tiles.map { |rows| builder.build_features(rows) }
        end
        
        tiles.each_with_index do |features, index|
          @list[index] += features
        end
      end
  
    end
    
    def render_metatile(index, size, options = {})
      
      if (size & (size - 1)) != 0
        raise ArgumentError, "size must be a power of 2"
      end
      
      mx = index.x & ~(size - 1)
      my = index.y & ~(size - 1)
      
      tiles = collect_features(Cover::Index.new(index.z, mx, my), size)
      
      tiles.map do |features|
        tile = JSON.dump(
          "scale" => @scale,
          "features" => features
        )
        
        if options[:compress] == :gzip
          s = StringIO.new
          gz = Zlib::GzipWriter.new(s)
          gz.write(tile)
          gz.close
          s.string
        else
          tile
        end
      end
      
    end
    
    def write_metatile(index, size, io, options = {})
      
      if (size & (size - 1)) != 0
        raise ArgumentError, "size must be a power of 2"
      end
      
      mx = index.x & ~(size - 1)
      my = index.y & ~(size - 1)
      
      data = render_metatile(index, size, options)
      
      io << ["META"].pack("a4")
      io << [size * size, mx, my, index.z].pack("l4")

      offset = 4 + (4 * 4) + (8 * size * size)

      data.each do |d|
        io << [offset, d.bytesize].pack("l2")
        offset += d.bytesize
      end

      data.each do |d|
        io << d
      end
      
    end
  
    def render_tile(index, options = {})
      
      features = collect_features(index, 1).first
      
      tile = JSON.dump(
        "scale" => @scale,
        "features" => features
      )
      
      if options[:compress] == :gzip
        s = StringIO.new("")
        gz = Zlib::GzipWriter.new(s)
        gz.write(tile)
        gz.close
        s.string
      else
        tile
      end
    
    end
    
    def write_tile(index, io, options = {})
      
      io << render_tile(index, options)
      
    end
    
    protected
    
      def collect_features(index, size)
  
        collector = FeatureCollector.new(index, @scale, size)
        @block.call(index, collector)
        features = collector.instance_eval { @list }
      
      end
  
  end

end
