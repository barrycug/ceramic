require "json"

module Cover

  class Maker
  
    def initialize(options = {}, &block)
    
      if !block_given?
        raise ArgumentError, "A block must be given"
      end
      
      if !options.has_key?(:scale)
        raise ArgumentError, ":scale must be specified"
      end
    
      @scale = options[:scale]
      @block = block
    
    end
  
    class FeatureCollector
    
      def initialize(index, scale)
        @index = index
        @scale = scale
        @list = []
      end
    
      def make(source, builder)
        append(build(source, builder))
      end
  
      def build(source, builder)
        builder.build_features(source.select_rows(@index, @scale))
      end
    
      def append(features)
        @list += features
      end
  
    end
  
    def render_tile(index)
    
      collector = FeatureCollector.new(index, @scale)
      @block.call(index, collector)
      features = collector.instance_eval { @list }
    
      JSON.dump(
        "scale" => @scale,
        "features" => features
      )
    
    end
  
  end

end
