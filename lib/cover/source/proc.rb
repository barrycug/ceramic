module Cover
  
  module Source
    
    class Proc
  
      class << self
    
        def build(options = {}, &block)
          instance = self.new
          instance.query = block if block_given?
          instance
        end
  
      end
  
      attr_accessor :query
  
      def initialize
        @query = proc { |i| [] }
      end
  
      def query(index, &block)
        if block_given?
          @query.call(index).each { |f| yield f }
        else
          @query.call(index)
        end
      end
  
    end
    
  end
  
end
