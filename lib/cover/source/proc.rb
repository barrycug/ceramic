module Cover
  
  module Source
    
    class Proc
  
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
