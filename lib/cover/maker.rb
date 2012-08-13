require "zlib"

module Cover
  
  class Maker
  
    def initialize(options = {})
      @scale = options[:scale]
      @pairs = options[:pairs]
    end
  
    def write_tile(tile_index, io)
      io << "{"
      io << "\"scale\":#{@scale},"
      io << "\"features\":["
      write_tile_features(tile_index, io)
      io << "]"
      io << "}"
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
          
          tile_index = TileIndex.new(mz, mx + x, my + y)
          
          # Record the position of this tile
          
          tile_position = io.pos
          
          # Write the tile (gzipped)
          
          gz = Zlib::GzipWriter.new(io, 9)
          write_tile(tile_index, gz)
          gz.finish
          
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
  
    private
  
      def write_tile_features(tile_index, io)
        
        written = false
        
        @pairs.each do |pair|
          
          source, writer = *pair
          
          source.select_rows(tile_index, @scale).each.with_index do |row, index|
            io << "," if written || index > 0
            
            writer.write_feature(row, io)
            written = true
          end
          
        end
        
      end
  
  end

end
