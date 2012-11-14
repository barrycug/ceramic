module Ceramic
  
  module Commands
  
    class Tirex
    
      def self.run!
        Backends::Tirex.run!
      end
    
    end
    
  end
  
end
