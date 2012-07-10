module Cover
  
  class Builder
  
    def initialize(&block)
      if !block_given?
        raise ArgumentError, "A block must be given"
      end
    
      @block = block
    end
  
    def build_features(rows)
      rows.map { |row| @block.call(row) }.compact
    end
  
  end
  
end
