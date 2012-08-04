require "pg"

module Cover
  module Source
    
    class OSM2PGSQL
      
      class Result
        
        def initialize(pg_results)
          @pg_results = pg_results
        end
        
        def each
          @pg_results.each do |result|
            result.each { |row| yield row }
          end
        end
        
        def count
          @pg_results.inject(0) { |sum, result| sum + result.ntuples }
        end
        
        def clear
          @pg_results.each { |result| result.clear }
        end
        
      end
      
      class SelectionBuilder < ::SelectionBuilder
        
        protected
        
          def parse_conditions(conditions)
            conditions.inject({}) do |hash, (name, value)|
              hash[name] = if name == :zoom
                parse_zoom(value)
              else
                value
              end
              hash
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
        @selections = SelectionBuilder.collect_selections(&block)
      end
      
      def select(tile_index, scale)
        point = point_query_arguments(tile_index, scale)
        line = line_query_arguments(tile_index, scale)
        polygon = polygon_query_arguments(tile_index, scale)
        
        Result.new([connection.exec(*polygon), connection.exec(*line), connection.exec(*point)])
      end
      
      private
      
        def point_query_arguments(tile_index, scale)
          
          bounds = tile_index.bounds
          
          [<<-END]
SELECT
  ST_AsGeoJSON(
    ST_TransScale(
      way,
      #{-bounds[:left]},
      #{-bounds[:top]},
      #{scale.to_f / (bounds[:right] - bounds[:left])},
      #{-scale.to_f / (bounds[:top] - bounds[:bottom])}
    ),
    0
  ) AS way,
  osm_id
FROM
  planet_osm_point
WHERE
  ST_Intersects(way, ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, 900913))
END

        end
      
        def line_query_arguments(tile_index, scale)
          
          bounds = tile_index.bounds
          
          [<<-END]
SELECT
  ST_AsGeoJSON(
    ST_TransScale(
      ST_Intersection(
        ST_SimplifyPreserveTopology(way, #{bounds[:width] / scale.to_f}),
        ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, 900913)
      ),
      #{-bounds[:left]},
      #{-bounds[:top]},
      #{scale.to_f / (bounds[:right] - bounds[:left])},
      #{-scale.to_f / (bounds[:top] - bounds[:bottom])}
    ),
    0
  ) AS way,
  osm_id
FROM
  planet_osm_line
WHERE
  ST_Intersects(way, ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, 900913))
END

        end
      
        def polygon_query_arguments(tile_index, scale)
          
          bounds = tile_index.bounds
          
          [<<-END]
SELECT
  ST_AsGeoJSON(
    ST_TransScale(
      ST_Intersection(
        ST_SimplifyPreserveTopology(ST_Buffer(way, 0), #{bounds[:width] / scale.to_f}),
        ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, 900913)
      ),
      #{-bounds[:left]},
      #{-bounds[:top]},
      #{scale.to_f / (bounds[:right] - bounds[:left])},
      #{-scale.to_f / (bounds[:top] - bounds[:bottom])}
    ),
    0
  ) AS way,
  osm_id
FROM
  planet_osm_polygon
WHERE
  ST_Intersects(way, ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, 900913))
END

        end
      
    end
    
  end
end
