module Cover
  
  class Tileset
  
    class << self
      
      def parse_file(path)
        src = File.read(path)
        src.sub!(/^__END__\n.*\Z/m, '')
        eval "Cover::Tileset.build {\n" + src + "\n}", TOPLEVEL_BINDING, path
      end
    
      def build(options = {}, &block)
        Builder::TilesetBuilder.build(options, &block)
      end
    
    end
  
    attr_accessor :sources
    attr_accessor :scale
    attr_accessor :margin
    attr_accessor :writer
  
    def initialize
      @sources = []
      @scale = 1024
      @margin = 0
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
  
    def write(index, io, options = {})
      if options[:compress]
        io = Zlib::GzipWriter.new(io, 9)
      end
      
      io << "{"
      io << "\"scale\":#{scale},"
      io << "\"features\":["
    
      first = true
    
      sources.each do |source|
        
        source.query(index, :scale => scale, :margin => margin) do |feature|
          io << "," unless first
          writer.write(feature, io)
          first = false
        end
        
      end
    
      io << "]"
      io << "}"
      
      if options[:compress]
        io.finish
      end
    end
    
    def write_metatile(metatile_index, io, options = {})
      
      size = options[:size] || 8
      
      mx = metatile_index.x
      my = metatile_index.y
      mz = metatile_index.z
      
      io << ["META"].pack("a4")
      io << [size * size, mx, my, mz].pack("l4")
      
      # Record the position where the table of contents will be written
      
      toc_position = io.pos
      
      # Seek to the position of the first tile
      
      io.pos += 8 * size * size
      
      # Write the tiles, storing positions and sizes in the table of contents
      
      toc = []
      
      for x in 0...size
        for y in 0...size
          
          tile_index = Index.new(mz, mx + x, my + y)
          
          # Record the position of this tile
          
          tile_position = io.pos
          
          # Write the tile
          
          write(tile_index, io, :compress => options[:compress])
          
          # Record the size of the tile
          
          tile_size = io.pos - tile_position
          
          # Add the position and size to the table of contents
          
          toc += [tile_position, tile_size]
          
        end
      end
      
      # Seek to and write the table of contents
      
      io.pos = toc_position
      io << toc.pack("l*")
      
      # Seek to the end of the stream
      
      io.seek(0, IO::SEEK_END)
      
    end
  
  end

end
