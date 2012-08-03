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
  
    private
  
      def write_tile_features(tile_index, io)
        @pairs.each do |pair|
          source, writer = *pair
          result = source.select(tile_index, @scale)
          index = 0
          result.each do |row|
            written = writer.write_feature(row, io)
            index += 1
            io << "," if index < result.num_tuples && written
          end
          result.clear
        end
      end
  
  end

end
