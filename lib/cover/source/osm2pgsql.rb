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
          @options = {}
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
      
      def initialize(&block)
        
        @srid = 900913
        @queries = QueryCollector.collect_queries(&block)
        
      end
      
      def select_rows(tile_index, scale)
        
        statements = statements_for_zoom(tile_index.z)
        params = params_for_index_and_scale(tile_index, scale)
        
        Enumerator.new do |y|
          
          statements.each do |statement|
            connection.exec(statement, params) do |result|
              result.each do |row|
                y << row unless row["way"] == "{\"type\":\"GeometryCollection\",\"geometries\":[]}"
              end
            end
          end
          
        end
        
      end
      
      private
      
        def statements_for_zoom(zoom)
          
          @queries.inject([]) do |statements, query|
            
            selections = query.selections.select do |selection|
              selection.options[:zoom] == nil || selection.options[:zoom].include?(zoom)
            end
            
            next statements if selections.empty?
            
            query.tables.each do |table|
              
              case table
              when :point
                statements << "SELECT osm_id, #{point_geometry_column} FROM planet_osm_point WHERE ST_Intersects(way, ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int))"
              when :line
                statements << "SELECT osm_id, #{line_geometry_column} FROM planet_osm_line WHERE ST_Intersects(way, ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int))"
              when :polygon
                statements << "SELECT osm_id, #{polygon_geometry_column} FROM planet_osm_polygon WHERE ST_Intersects(way, ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int))"
              end
              
            end
            
            statements
            
          end

        end
        
        def point_geometry_column
          <<-END
ST_AsGeoJSON(
  ST_TransScale(
    way,
    -$1::float,
    -$2::float,
    $7::float / $5::float,
    -$7::float / $6::float
  ),
  0
) AS way
END
        end
        
        def line_geometry_column
          <<-END
ST_AsGeoJSON(
  ST_TransScale(
    ST_Intersection(
      ST_SimplifyPreserveTopology(way, $5::float / $7::float),
      ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int)
    ),
    -$1::float,
    -$2::float,
    $7::float / $5::float,
    -$7::float / $6::float
  ),
  0
) AS way
END
        end
        
        def polygon_geometry_column
          <<-END
ST_AsGeoJSON(
  ST_TransScale(
    ST_ForceRHR(
      ST_Intersection(
        ST_Buffer(ST_SimplifyPreserveTopology(way, $5::float / $7::float), 0),
        ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int)
      )
    ),
    -$1::float,
    -$2::float,
    $7::float / $5::float,
    -$7::float / $6::float
  ),
  0
) AS way,
ST_AsGeoJSON(
  ST_TransScale(
    ST_PointOnSurface(ST_Buffer(way, 0)),
    -$1::float,
    -$2::float,
    $7::float / $5::float,
    -$7::float / $6::float
  ),
  0
) AS point
END
        end
        
        def columns_and_conditions(zoom, table)
          
          # find all selections for the table
          
          table_selections = @selections.select do |s|
            !s.context.has_key?(:table) || s.context[:table].include?(table)
          end
          
          # if one of the selections includes this zoom level, add its sql
          # to the column_conditions for each of the column selections
          # it declares.
          
          column_conditions = Hash.new { |hash, key| hash[key] = [] }
          
          table_selections.each do |s|
            if !s.context.has_key?(:zoom) || s.context[:zoom].include?(zoom)
              s.selection.each do |column|
                if s.context.has_key?(:sql)
                  column_conditions[column] << s.context[:sql].map { |s| "(#{s})" }.join(" AND ")
                else
                  column_conditions[column] << "TRUE"
                end
              end
            end
          end
          
          # prepare cases for each column
    
          columns = column_conditions.map do |(column, conditions)|
            condition = conditions.map { |c| "(#{c})" }.join(" OR ")
            "CASE WHEN #{condition} THEN #{@connection.quote_ident(column)} ELSE NULL END AS #{@connection.quote_ident(column)}"
          end.join(", ")
          
          # prepare conditions
    
          conditions = (["FALSE"] + table_selections.map do |s|
            if !s.context.has_key?(:zoom) || s.context[:zoom].include?(zoom)
              if s.context.has_key?(:sql)
                "(#{s.context[:sql].map { |s| "(#{s})" }.join(" AND ")})"
              else
                "TRUE"
              end
            else
              nil
            end
          end.compact).join(" OR ")
          
          # group
    
          group = column_conditions.map do |(column, conditions)|
            @connection.quote_ident(column)
          end.uniq.join(", ")
          
          [columns, conditions, group]
          
        end
      
        def params_for_index_and_scale(tile_index, scale)
          
          bounds = tile_index.bounds
          
          [
            bounds.left,    # 1
            bounds.top,     # 2
            bounds.right,   # 3
            bounds.bottom,  # 4
            bounds.width,   # 5
            bounds.height,  # 6
            scale,          # 7
            @srid           # 8
          ]
          
        end
      
    end
    
  end
end
