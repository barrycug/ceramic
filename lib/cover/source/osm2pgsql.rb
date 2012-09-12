require "pg"

module Cover
  module Source
    
    class OSM2PGSQL
      
      class QueryCollector
  
        Query = Struct.new(:tables, :options, :selections)
  
        def self.collect_queries(&block)
          collector = self.new
          collector.instance_exec(&block)
          collector.instance_variable_get(:@queries)
        end
  
        def initialize
          @queries = []
        end
  
        def query(*tables, &block)
          options = Hash === tables.last ? tables.pop : {}
          validate_query(tables, options)
    
          collector = SelectionCollector.new
          collector.instance_exec(&block)
          @queries << Query.new(tables, options, collector.instance_variable_get(:@selections))
        end

        protected

          def validate_query(table, options)
          end
  
      end

      class SelectionCollector
  
        Selection = Struct.new(:columns, :options)
  
        def initialize(options = {})
          @options = options
          @selections = []
        end
  
        def options(options = {}, &block)
          collector = SelectionCollector.new(merge_options(@options, options))
          collector.instance_exec(&block)
          @selections += collector.instance_variable_get(:@selections)
        end
  
        def select(columns = nil, options = {})
          validate_columns(columns)
          @selections << Selection.new(columns, merge_options(@options, options))
        end
  
        protected
  
          def validate_columns(columns)
            unless Array === columns
              raise ArgumentError, "columns must be an array"
            end
          end
    
          def merge_options(outer, inner)
            result = {}
            outer.each do |key, value|
              result[key] = value unless inner.has_key?(key)
            end
            inner.each do |key, value|
              result[key] = merge_option(key, outer[key], value)
            end
            result
          end
    
          def merge_option(key, outer, inner)
            case key
            when :zoom
              merge_zoom(outer, inner)
            when :sql
              merge_sql(outer, inner)
            else
              raise ArgumentError, "unknown option #{key}"
            end
          end
    
          def merge_zoom(outer, inner)
            inner = Cover::Util.parse_zoom(inner)
      
            if outer.nil?
              inner
            else
              if inner.end < outer.begin || inner.begin > outer.end
                raise ArgumentError, "zoom ranges must overlap"
              end
        
              Range.new(
                inner.begin > outer.begin ? inner.begin : outer.begin,
                inner.end < outer.end ? inner.end : outer.end
              )
            end
          end
    
          def merge_sql(outer, inner)
            if outer.nil?
              [inner]
            else
              outer + [inner]
            end
          end
  
      end
  
      WRAP_POINT = <<-END
ST_TransScale(
  $,
  -:viewbox_left, -:viewbox_top, :scale / :viewbox_width, -:scale / :viewbox_height
)
END
  
      WRAP_LINE = <<-END
ST_TransScale(
  ST_Intersection(
    $,
    ST_MakeEnvelope(:left, :top, :right, :bottom, :srid)
  ),
  -:viewbox_left, -:viewbox_top, :scale / :viewbox_width, -:scale / :viewbox_height
)
END
  
      WRAP_LINE_WHOLE = <<-END
ST_TransScale(
  $,
  -:viewbox_left, -:viewbox_top, :scale / :viewbox_width, -:scale / :viewbox_height
)
END
  
      WRAP_POLYGON = <<-END
ST_TransScale(
  ST_ForceRHR(
    ST_Intersection(
      ST_Buffer($, 0),
      ST_MakeEnvelope(:left, :top, :right, :bottom, :srid)
    )
  ),
  -:viewbox_left, -:viewbox_top, :scale / :viewbox_width, -:scale / :viewbox_height
)
END
  
      WRAP_POLYGON_WHOLE = <<-END
ST_TransScale(
  ST_ForceRHR(
    $
  ),
  -:viewbox_left, -:viewbox_top, :scale / :viewbox_width, -:scale / :viewbox_height
)
END
      
      attr_accessor :connection
      
      def initialize(options = {}, &block)
        
        @table_prefix = options[:prefix] || "planet_osm"
        @geometry_column = options[:geometry_column] || "way"
        @geometry_srid = options[:geometry_srid] || 900913
        @margin = options[:margin] || 0
        
        @queries = QueryCollector.collect_queries(&block)
        
      end
      
      def select_rows(tile_index, scale)
        
        postgis_queries = postgis_queries_for_zoom(tile_index.z)
        
        bounds = tile_index.bounds
        
        parameters = {
          "scale" => [scale.to_f, "float"],
          
          "viewbox_left" => [bounds.left, "float"],
          "viewbox_top" => [bounds.top, "float"],
          "viewbox_bottom" => [bounds.bottom, "float"],
          "viewbox_right" => [bounds.right, "float"],
          "viewbox_width" => [bounds.width, "float"],
          "viewbox_height" => [bounds.height, "float"],
          
          "left" => [bounds.left - (bounds.width * @margin), "float"],
          "top" => [bounds.top + (bounds.height * @margin), "float"],
          "bottom" => [bounds.bottom - (bounds.height * @margin), "float"],
          "right" => [bounds.right + (bounds.height * @margin), "float"],
          "width" => [bounds.width + (bounds.width * @margin * 2), "float"],
          "height" => [bounds.height + (bounds.height * @margin * 2), "float"],
          
          "unit" => [bounds.width / scale.to_f, "float"],
          "srid" => [@geometry_srid, "int"]
        }
        
        Enumerator.new do |y|
          
          postgis_queries.each do |postgis_query|
            arguments = PostGISQuery.build_exec_arguments(postgis_query, parameters)
            
            connection.exec(*arguments) do |result|
              result.each { |row| y << row }
            end
          end
          
        end
        
      end
      
      private
      
        def postgis_queries_for_zoom(zoom)
          
          @queries.inject([]) do |statements, query|
            
            selections = query.selections.select do |selection|
              selection.options[:zoom] == nil || selection.options[:zoom].include?(zoom)
            end
            
            next statements if selections.empty?
            
            statements + query.tables.map do |table|
              build_postgis_query(table, query.options, selections)
            end
            
          end

        end
        
        def build_postgis_query(table, options, selections)
          
          # table name
          
          table_name = case table
            when :point
              @table_prefix + "_point"
            when :line
              @table_prefix + "_line"
            when :polygon
              @table_prefix + "_polygon"
          end
          
          # geometry
          
          if options[:geometry]
            geometry_wrap_expressions = [options[:geometry]]
          else
            geometry_wrap_expressions = [@geometry_column]
          end
          
          if Numeric === options[:simplify]
            geometry_wrap_expressions.unshift("ST_SimplifyPreserveTopology($, :unit * #{options[:simplify]})")
          elsif options[:simplify] != false
            geometry_wrap_expressions.unshift("ST_SimplifyPreserveTopology($, :unit)")
          end
          
          case table
          when :point
            geometry_wrap_expressions.unshift(WRAP_POINT)
          when :line
            if options[:intersection] == false
              geometry_wrap_expressions.unshift(WRAP_LINE_WHOLE)
            else
              geometry_wrap_expressions.unshift(WRAP_LINE)
            end
          when :polygon
            if options[:intersection] == false
              geometry_wrap_expressions.unshift(WRAP_POLYGON_WHOLE)
            else
              geometry_wrap_expressions.unshift(WRAP_POLYGON)
            end
          end
          
          geometry = { @geometry_column => geometry_wrap_expressions }
          
          if table == :polygon && options[:point] != false
            geometry[:point] = [WRAP_POINT, "ST_PointOnSurface(ST_Buffer($, 0))", @geometry_column]
          end
          
          # columns
          
          column_conditions = Hash.new { |hash, key| hash[key] = [] }
          column_expressions = {}
          
          selections.each do |selection|
              
            selection.columns.each do |column|
              
              if Array === column
                column, expression = *column
              else
                expression = @connection.quote_ident(column.to_s)
              end
              
              column_conditions[column] << (["TRUE"] + (selection.options[:sql] || [])).join(" AND ")
              column_expressions[column] = expression
              
            end
            
          end
          
          columns = column_conditions.inject({}) do |hash, (column, conditions)|
            
            name = column
            expression = column_expressions[column]
            condition = conditions.map { |c| "(#{c})" }.join(" OR ")
            
            hash[name] = "CASE WHEN #{condition} THEN #{expression} ELSE NULL END"
            hash
            
          end
          
          # conditions
          
          conditions = (["FALSE"] + selections.map do |selection|
            "(" + (["TRUE"] + (selection.options[:sql] || [])).join(" AND ") + ")"
          end).join(" OR ")
          
          # group
          
          if options[:group]
            group = selections.inject([]) { |c, s| c | s.columns }.map { |c| @connection.quote_ident(c.to_s) }
          end
          
          # query
          
          PostGISQuery.new(
            :table => table_name,
            :columns => columns,
            :geometry => geometry,
            :conditions => conditions,
            :group => group,
            :intersection_geometry_column => @geometry_column
          )
          
        end
      
    end
    
  end
end
