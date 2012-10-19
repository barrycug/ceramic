module Ceramic
  module Builder
    
    class ProcSourceBuilder
  
      class << self
        def build(options = {}, &block)
          source = Source::Proc.new
          source.query = block
          source
        end
      end
  
    end
    
  end
end
