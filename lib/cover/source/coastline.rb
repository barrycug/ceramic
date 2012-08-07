require "pg"

module Cover
  module Source
    
    class Coastline
      
      attr_accessor :connection
      
      def initialize(table, options = {})
        @table = table
        @geometry_column = options[:geometry] || "the_geom"
        @srid = options[:srid] || 3857
      end
      
      def select_rows(tile_index, scale)
 
        query = <<-END
SELECT
  ST_AsGeoJSON(
    #{@connection.quote_ident(@geometry_column)},
    0
  ) AS #{@connection.quote_ident(@geometry_column)}
FROM (
  SELECT
    ST_TransScale(
      ST_ForceRHR(
        ST_Intersection(
          ST_SimplifyPreserveTopology(
            ST_Union(ST_Buffer(#{@connection.quote_ident(@geometry_column)}, 0)),
            $5::float / $7::float
          ),
          ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int)
        )
      ),
      -$1::float,
      -$2::float,
      $7::float / $5::float,
      -$7::float / $6::float
    ) AS #{@connection.quote_ident(@geometry_column)}
  FROM
    #{@table}
  WHERE
    ST_MakeEnvelope($1::float, $2::float, $3::float, $4::float, $8::int) && #{@connection.quote_ident(@geometry_column)}
) q
WHERE NOT ST_IsEmpty(#{@connection.quote_ident(@geometry_column)})
END
        
        bounds = tile_index.bounds
        
        params = [
          bounds[:left],    # 1
          bounds[:top],     # 2
          bounds[:right],   # 3
          bounds[:bottom],  # 4
          bounds[:width],   # 5
          bounds[:height],  # 6
          scale,            # 7
          @srid             # 8
        ]
        
        Enumerator.new do |y|
          connection.exec(query, params) do |result|
            result.each do |row|
              y << row
            end
          end
        end
        
      end
      
    end
    
  end
end
