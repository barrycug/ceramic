require "pg"

module Cover
  
  class Maker
    
    attr_reader :sources
    
    def initialize(options = {})
      
      # TODO: validate options
      
      @granularity = options[:granularity]
      @sources = []
      @renderer = Renderer.new
      
    end
    
    def render_tile(index)
      
      rows = []
      
      @sources.each do |source|
        rows += source.select_rows(index, @granularity)
      end
      
      @renderer.render(rows, @granularity)
      
    end
    
  end
  
end
