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
      
      attr_accessor :connection
      
      def initialize(options = {}, &block)
        
        @table_prefix = options[:prefix] || "planet_osm"
        @geometry_column = options[:geometry_column] || "way"
        @geometry_srid = options[:geometry_srid] || 900913
        
        @queries = QueryCollector.collect_queries(&block)
        
      end
      
      def select_rows(tile_index, scale)
        
        statements = statements_for_zoom(tile_index.z)
        
        bounds = tile_index.bounds
        
        parameters = {
          "scale" => [scale.to_f, "float"],
          "left" => [bounds.left, "float"],
          "top" => [bounds.top, "float"],
          "bottom" => [bounds.bottom, "float"],
          "right" => [bounds.right, "float"],
          "width" => [bounds.width, "float"],
          "height" => [bounds.height, "float"],
          "unit" => [bounds.width / scale.to_f, "float"],
          "srid" => [@geometry_srid, "int"]
        }
        
        Enumerator.new do |y|
          
          statements.each do |statement|
            arguments = build_arguments(statement, parameters)
            
            connection.exec(*arguments) do |result|
              result.each { |row| y << row }
            end
          end
          
        end
        
      end
      
      private
      
        def build_arguments(statement, parameters)
          result = statement.dup
          numbered = []
  
          parameters.each do |name, (value, type)|
            if result.gsub!(":#{name}", "$#{numbered.size + 1}::#{type}")
              numbered << value
            end
          end
  
          [result, numbered]
        end
      
        def statements_for_zoom(zoom)
          
          @queries.inject([]) do |statements, query|
            
            selections = query.selections.select do |selection|
              selection.options[:zoom] == nil || selection.options[:zoom].include?(zoom)
            end
            
            next statements if selections.empty?
            
            statements + query.tables.map do |table|
              build_statement(table, query.options, selections)
            end
            
          end

        end
        
        def build_statement(table, options, selections)
          
          subquery = build_subquery(table, options, selections)
          
          columns = selections.inject([]) { |c, s| c | s.columns }.map { |c| selection_column_name(c) }
          
          select_list = (["ST_AsGeoJSON(#{@connection.quote_ident(@geometry_column)}, 0) AS #{@connection.quote_ident(@geometry_column)}"] + columns).join(", ")
          
          "SELECT #{select_list} FROM (#{subquery}) q WHERE NOT ST_IsEmpty(#{@connection.quote_ident(@geometry_column)})"
          
        end
        
        def build_subquery(table, options, selections)
          
          geometry_expression = options[:geometry] || @connection.quote_ident(@geometry_column)
          
          if Numeric === options[:simplify]
            geometry_expression = "ST_SimplifyPreserveTopology(#{geometry_expression}, :unit * #{options[:simplify]})"
          elsif options[:simplify] != false
            geometry_expression = "ST_SimplifyPreserveTopology(#{geometry_expression}, :unit)"
          end
          
          geometry_item = (case table
            when :point
              wrap_point_geometry(geometry_expression)
            when :line
              wrap_line_geometry(geometry_expression)
            when :polygon
              wrap_polygon_geometry(geometry_expression)
          end) + " AS #{@connection.quote_ident(@geometry_column)}"
          
          column_conditions = Hash.new { |hash, key| hash[key] = [] }
          
          selections.each do |selection|
            selection.columns.each do |column|
              column_conditions[column] << (["TRUE"] + (selection.options[:sql] || [])).join(" AND ")
            end
          end
          
          conditional_columns = column_conditions.map do |(column, conditions)|
            condition = conditions.map { |c| "(#{c})" }.join(" OR ")
            "CASE WHEN #{condition} THEN #{selection_column_value(column)} ELSE NULL END AS #{selection_column_name(column)}"
          end
          
          select_list = ([geometry_item] + conditional_columns).join(", ")
          
          table_name = case table
            when :point
              @table_prefix + "_point"
            when :line
              @table_prefix + "_line"
            when :polygon
              @table_prefix + "_polygon"
          end
          
          intersection = "#{@connection.quote_ident(@geometry_column)} && ST_MakeEnvelope(:left, :top, :right, :bottom, :srid)"
          
          conditions = (["FALSE"] + selections.map do |selection|
            "(" + (["TRUE"] + (selection.options[:sql] || [])).join(" AND ") + ")"
          end).join(" OR ")
          
          if options[:group]
            columns = selections.inject([]) { |c, s| c | s.columns }.map { |c| selection_column_name(c) }
            group = columns.join(", ")
          end
          
          query = ""
          query += "SELECT #{select_list} "
          query += "FROM #{table_name} "
          query += "WHERE (#{intersection}) "
          query += "AND (#{conditions}) "
          query += "GROUP BY #{group} " if group
          
          query
          
        end
        
        def selection_column_name(selection_column)
          if Array === selection_column
            selection_column_name(selection_column[0])
          elsif Symbol === selection_column
            @connection.quote_ident(selection_column.to_s)
          else
            selection_column
          end
        end
        
        def selection_column_value(selection_column)
          if Array === selection_column
            selection_column[1]
          elsif Symbol === selection_column
            @connection.quote_ident(selection_column.to_s)
          else
            selection_column
          end
        end
        
        def wrap_point_geometry(column)
          <<-END
ST_TransScale(
  #{column},
  -:left,
  -:top,
  :scale / :width,
  -:scale / :height
)
END
        end
        
        def wrap_line_geometry(column)
          <<-END
ST_TransScale(
  ST_Intersection(
    #{column},
    ST_MakeEnvelope(:left, :top, :right, :bottom, :srid)
  ),
  -:left,
  -:top,
  :scale / :width,
  -:scale / :height
)
END
        end
        
        def wrap_polygon_geometry(column)
          <<-END
ST_TransScale(
  ST_ForceRHR(
    ST_Intersection(
      ST_Buffer(#{column}, 0),
      ST_MakeEnvelope(:left, :top, :right, :bottom, :srid)
    )
  ),
  -:left,
  -:top,
  :scale / :width,
  -:scale / :height
)
END
        end
      
    end
    
  end
end
