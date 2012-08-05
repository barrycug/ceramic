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
          source.select_rows(tile_index, @scale).each.with_index do |row, index|
            io << "," if index > 0
            writer.write_feature(row, io)
          end
        end
      end
  
  end

end
