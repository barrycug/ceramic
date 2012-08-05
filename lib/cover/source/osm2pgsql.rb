require "pg"

module Cover
  module Source
    
    class OSM2PGSQL
      
      class SelectionBuilder < ::SelectionBuilder
        
        protected
        
          def validate_selection(selection)
            unless Array === selection
              raise ArgumentError, "selection must be an array"
            end
          end
        
          def merge_condition(key, outer, inner)
            case key
            when :zoom
              merge_zoom(outer, inner)
            when :table
              merge_table(outer, inner)
            when :sql
              super(key, outer, inner)
            else
              raise ArgumentError, "unknown condition key: #{key}"
            end
          end
          
          def merge_table(outer, inner)
            inner = Array === inner ? inner : [inner]
            
            if outer.nil?
              inner
            else
              merged = outer & inner
              
              if merged.empty?
                raise ArgumentError, "table set intersections must not be empty"
              end
              
              merged
            end
          end
          
          def merge_zoom(outer, inner)
            inner = parse_zoom(inner)
            
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

          def parse_zoom(zoom)
            if String === zoom
              if zoom =~ /(\d+)?-(\d+)?/
                Range.new($1.nil? ? 0 : $1.to_i, $2.nil? ? 1.0/0 : $2.to_i)
              elsif zoom =~ /(\d+)/
                Range.new($1.to_i, $1.to_i)
              else
                raise ArgumentError, "invalid zoom specifier"
              end
            elsif Integer === zoom
              Range.new(zoom, zoom)
            elsif Range === zoom
              zoom
            else
              raise ArgumentError, "invalid zoom specifier"
            end
          end
        
      end
      
      attr_accessor :connection
      
      def initialize(&block)
        
        @srid = 900913
        @selections = SelectionBuilder.collect_selections(&block)
        
      end
      
      def select_rows(tile_index, scale)
        
        queries = queries_for_zoom(tile_index.z)
        params = params_for_index_and_scale(tile_index, scale)
        
        Enumerator.new do |y|
          
          queries.each do |query|
            connection.exec(query, params) do |result|
              result.each do |row|
                y << row unless row["way"] == "{\"type\":\"GeometryCollection\",\"geometries\":[]}"
              end
            end
          end
          
        end
        
      end
      
      private
      
        def queries_for_zoom(zoom)
          
          queries = []
          
          columns, conditions = *columns_and_conditions(zoom, :polygon)
          geometry = polygon_geometry_column
          queries << "SELECT #{geometry}, #{columns} FROM planet_osm_polygon WHERE (#{conditions}) AND ST_Intersects(way, ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int))"
          
          columns, conditions = *columns_and_conditions(zoom, :line)
          geometry = line_geometry_column
          queries << "SELECT #{geometry}, #{columns} FROM planet_osm_line WHERE (#{conditions}) AND ST_Intersects(way, ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int))"
          
          columns, conditions = *columns_and_conditions(zoom, :roads)
          geometry = roads_geometry_column
          queries << "SELECT #{geometry}, #{columns} FROM planet_osm_roads WHERE (#{conditions}) AND ST_Intersects(way, ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int))"
          
          columns, conditions = *columns_and_conditions(zoom, :point)
          geometry = point_geometry_column
          queries << "SELECT #{geometry}, #{columns} FROM planet_osm_point WHERE (#{conditions}) AND ST_Intersects(way, ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int))"
          
          queries

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
        
        def roads_geometry_column
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
    ST_Intersection(
      ST_Buffer(ST_SimplifyPreserveTopology(way, $5::float / $7::float), 0),
      ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int)
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
          
          # find all selections for the planet_osm_line table
          
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
    
          columns = (["osm_id"] + column_conditions.map do |(column, conditions)|
            condition = conditions.map { |c| "(#{c})" }.join(" OR ")
            "CASE WHEN #{condition} THEN #{@connection.quote_ident(column)} ELSE NULL END AS #{@connection.quote_ident(column)}"
          end).join(", ")
          
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
          
          [columns, conditions]
          
        end
      
        def params_for_index_and_scale(tile_index, scale)
          
          bounds = tile_index.bounds
          
          [
            bounds[:left],    # 1
            bounds[:top],     # 2
            bounds[:right],   # 3
            bounds[:bottom],  # 4
            bounds[:width],   # 5
            bounds[:height],  # 6
            scale,            # 7
            @srid             # 8
          ]
          
        end
      
    end
    
  end
end
