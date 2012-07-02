require "pg"

module Cover
  module Sources
    
    class PostGIS
      
      def initialize(options = {})
        
        unless options.has_key?(:connection)
          raise ArgumentError, "No database connection specified"
        end
        
        unless options.has_key?(:table)
          raise ArgumentError, "No table or subquery specified"
        end
        
        unless options.has_key?(:geometry_srid)
          raise ArgumentError, "No geometry SRID specified"
        end
        
        unless options.has_key?(:geometry_column)
          raise ArgumentError, "No geometry column specified"
        end
        
        unless options.has_key?(:geometry_type)
          raise ArgumentError, "No geometry type specified"
        end
        
        unless [:point, :line, :polygon].include?(options[:geometry_type])
          raise ArgumentError, "Geometry type must be :point, :line, or :polygon"
        end
        
        unless options[:zoom] == nil || options[:zoom].is_a?(Array)
          raise ArgumentError, "Zoom filter must be an array"
        end
        
        @connection = options[:connection]
        @table = options[:table]
        @geometry_srid = options[:geometry_srid]
        @geometry_column = options[:geometry_column]
        @geometry_type = options[:geometry_type]
        @simplify = options[:simplify]
        @zoom = options[:zoom]
        
      end
      
      # Query the database for rows in the tile specified by index, at the
      # specified granularity.
      
      def select_rows(index, granularity)
        
        if @zoom && !@zoom.include?(index.z)
          return []
        end
        
        rows = []
        
        @connection.exec(*query_arguments(index, granularity)).each do |row|
          rows << process_result_row(row)
        end
        
        rows
        
      end
      
      protected
      
        # Remove the PostGIS geometry column from the result row, leaving the
        # tag columns and the GeoJSON geometry column, "json".
      
        def process_result_row(row)
          row.reject { |k, v| k == @geometry_column }
        end
      
        def query_arguments(index, granularity)
          
          case @geometry_type
          when :point
            point_query_arguments(index, granularity)
          when :line
            line_query_arguments(index, granularity)
          when :polygon
            polygon_query_arguments(index, granularity)
          end
          
        end
        
        # FIXME: the SRID option really only serves to choose between 900913 and
        # 3857, since we don't transform the box used for intersection or the input
        # to ST_TransScale.
        
        def point_query_arguments(index, granularity)
          
          granule = index.width / granularity.to_f
          bbox = "ST_MakeEnvelope(#{index.left}::float, #{index.top}::float, #{index.right}::float, #{index.bottom}::float, #{@geometry_srid})"
          
          params = [
            -index.left, -index.top, granularity.to_f / index.width, granularity.to_f / index.height,
            index.left, index.top, index.right, index.bottom
          ]
          
          subquery = @table.gsub("!granule!", granule.to_s).gsub("!bbox!", bbox.to_s)
          
          [<<-END, params]
SELECT
  *,
  ST_AsGeoJSON(
    ST_TransScale(#{quoted_geometry_column}, $1::float, $2::float, $3::float, $4::float), 0
  ) AS json
FROM
  #{subquery}
WHERE
  #{quoted_geometry_column} && ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
END
          
        end
        
        def line_query_arguments(index, granularity)
          
          granule = index.width / granularity.to_f
          bbox = "ST_MakeEnvelope(#{index.left}::float, #{index.top}::float, #{index.right}::float, #{index.bottom}::float, #{@geometry_srid})"
          
          subquery = @table.gsub("!granule!", granule.to_s).gsub("!bbox!", bbox.to_s)
          
          # FIXME: reduce duplication
          
          if @simplify && @simplify > 0
            
            tolerance = @simplify * granule
          
            params = [
              -index.left, -index.top, granularity.to_f / index.width, granularity.to_f / index.height,
              index.left, index.top, index.right, index.bottom,
              tolerance
            ]
            
            [<<-END, params]
SELECT
  *,
  ST_AsGeoJSON(
    ST_TransScale(
      ST_Intersection(
        ST_SimplifyPreserveTopology(
          #{quoted_geometry_column},
          $9::float
        ),
        ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
      ),
      $1::float, $2::float, $3::float, $4::float
    ),
    0
  ) AS json
FROM
  #{subquery}
WHERE
  #{quoted_geometry_column} && ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
END
            
          else
            
            params = [
              -index.left, -index.top, granularity.to_f / index.width, granularity.to_f / index.height,
              index.left, index.top, index.right, index.bottom
            ]
            
            [<<-END, params]
SELECT
  *,
  ST_AsGeoJSON(
    ST_TransScale(
      ST_Intersection(
        #{quoted_geometry_column},
        ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
      ),
      $1::float, $2::float, $3::float, $4::float
    ),
    0
  ) AS json
FROM
  #{subquery}
WHERE
  #{quoted_geometry_column} && ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
END
            
          end
          
        end
        
        def polygon_query_arguments(index, granularity)
          
          granule = index.width / granularity.to_f
          bbox = "ST_MakeEnvelope(#{index.left}::float, #{index.top}::float, #{index.right}::float, #{index.bottom}::float, #{@geometry_srid})"
          
          subquery = @table.gsub("!granule!", granule.to_s).gsub("!bbox!", bbox.to_s)
          
          if @simplify && @simplify > 0
            
            tolerance = @simplify * granule
          
            params = [
              -index.left, -index.top, granularity.to_f / index.width, granularity.to_f / index.height,
              index.left, index.top, index.right, index.bottom,
              tolerance
            ]
            
            [<<-END, params]
SELECT
  *,
  ST_AsGeoJSON(
    ST_TransScale(
      ST_ForceRHR(
        ST_Intersection(
          ST_Buffer(
            ST_SimplifyPreserveTopology(
              #{quoted_geometry_column},
              $9::float
            ),
            0
          ),
          ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
        )
      ),
      $1::float, $2::float, $3::float, $4::float
    ),
    0
  ) AS json
FROM
  #{subquery}
WHERE
  #{quoted_geometry_column} && ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
END
            
          else
          
            params = [
              -index.left, -index.top, granularity.to_f / index.width, granularity.to_f / index.height,
              index.left, index.top, index.right, index.bottom
            ]
            
            [<<-END, params]
SELECT
  *,
  ST_AsGeoJSON(
    ST_TransScale(
      ST_ForceRHR(
        ST_Intersection(
          ST_Buffer(
            #{quoted_geometry_column},
            0
          ),
          ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
        )
      ),
      $1::float, $2::float, $3::float, $4::float
    ),
    0
  ) AS json
FROM
  #{subquery}
WHERE
  #{quoted_geometry_column} && ST_MakeEnvelope($5::float, $6::float, $7::float, $8::float, #{@geometry_srid})
END
            
          end

        end
        
        def quoted_geometry_column
          @connection.quote_ident(@geometry_column)
        end
      
    end
    
  end
end
