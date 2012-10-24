module Ceramic
  
  class Index
    
    EXTENT = 2 * Math::PI * 6378137 #:nodoc:
    ORIGIN = -(EXTENT / 2.0)        #:nodoc:
    
    Bounds = Struct.new(:left, :top, :right, :bottom, :width, :height)

    attr_reader :z, :x, :y

    def initialize(*arguments)
      if arguments.size == 1 && String === arguments[0] && arguments[0] =~ /(\d+)\/(\d+)\/(\d+)/
        @z = $1.to_i
        @x = $2.to_i
        @y = $3.to_i
      elsif arguments.size == 3 && arguments.all? { |a| Integer === a }
        @z, @x, @y = *arguments
      else
        raise ArgumentError, "expected a z/x/y path string or three integers"
      end
    end
    
    def to_s
      "#{z}/#{x}/#{y}"
    end

    def bounds
      unless instance_variable_defined?(:@bounds)
        scale = 2 ** z
        size = EXTENT / scale
        left = ORIGIN + (x * size)
        top = ORIGIN + ((scale - y) * size)
        
        @bounds = Bounds.new(left, top, left + size, top - size, size, size)
      end
      
      @bounds
    end

  end
    
end