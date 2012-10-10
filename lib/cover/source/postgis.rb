module Cover
  module Source
    
    class PostGIS
      
      class Table
        
        attr_accessor :table_expression
        attr_accessor :geometry_column
        
        def initialize(table_expression, options = {})
          @table_expression = table_expression
          @geometry_column = options[:geometry_column]
        end
        
        def postgis_query
          PostGISQuery.new(
            :table => @table_expression,
            :columns => { "id" => "osm_id" },
            :geometry => {
              "geometry" => ["ST_TransScale($, -:viewbox_left, -:viewbox_top, :scale / :viewbox_width, -:scale / :viewbox_height)", @geometry_column]
            },
            :intersection_geometry_column => @geometry_column
          )
        end
        
      end
      
      attr_accessor :tables
      attr_accessor :connection_info
      
      def initialize
        @tables = []
      end
      
      def setup
        @connection = PG.connect(connection_info)
      end
      
      def teardown
        @connection.close
      end
      
      def query(index, &block)
        
        bounds = index.bounds
        
        margin = 0
        scale = 1024.0
        srid = 900913
        
        parameters = {
          "scale" => [scale, "float"],
          
          "viewbox_left" => [bounds.left, "float"],
          "viewbox_top" => [bounds.top, "float"],
          "viewbox_bottom" => [bounds.bottom, "float"],
          "viewbox_right" => [bounds.right, "float"],
          "viewbox_width" => [bounds.width, "float"],
          "viewbox_height" => [bounds.height, "float"],
          
          "left" => [bounds.left - (bounds.width * margin), "float"],
          "top" => [bounds.top + (bounds.height * margin), "float"],
          "bottom" => [bounds.bottom - (bounds.height * margin), "float"],
          "right" => [bounds.right + (bounds.height * margin), "float"],
          "width" => [bounds.width + (bounds.width * margin * 2), "float"],
          "height" => [bounds.height + (bounds.height * margin * 2), "float"],
          
          "unit" => [bounds.width / scale, "float"],
          "area" => [bounds.width * bounds.height, "float"],
          "srid" => [srid, "int"]
        }
        
        tables.each do |table|
      
          arguments = PostGISQuery.build_exec_arguments(table.postgis_query, parameters)
          
          @connection.exec(*arguments) do |result|
            result.each { |row| yield row }
          end
        
        end
        
      end
      
    end
    
  end
end
