module Cover
  module Builder
    
    class PostGISSourceBuilder
  
      class << self
        def build(options = {}, &block)
          builder = self.new(options)
          builder.instance_exec(&block)
          builder.instance_variable_get(:@source)
        end
      end
    
      def initialize(options = {})
        @source = Source::PostGIS.new
        @source.connection_info = options[:connection_info]
      end

      def table(table_expression, options = {})
        @source.tables << Source::PostGIS::Table.new(table_expression, options)
      end
  
    end
    
  end
end
