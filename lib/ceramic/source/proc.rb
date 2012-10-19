module Ceramic
  
  module Source
    
    class Proc
  
      attr_accessor :query
  
      def initialize
        @query = proc { |i| [] }
      end
  
      def query(index, options = {}, &block)
        @query.call(index).each { |f| yield f }
      end
  
    end
    
  end
  
end
