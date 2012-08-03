require "pg"

module Cover
    
  class Selection

    attr_reader :columns
    attr_reader :zoom
    attr_reader :sql

    def initialize(options = {})
      @columns = options[:columns]
      @zoom = parse_zoom(options[:zoom])
      @sql = options[:sql]
    end

    private

      def parse_zoom(zoom)
        if String === zoom
          if zoom =~ /(\d+)?-(\d+)?/
            Range.new($1.nil? ? -1.0/0 : $1.to_i, $2.nil? ? 1.0/0 : $2.to_i)
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
  
  class Source
  
    attr_accessor :connection
  
    def initialize(options = {})
      @table = options[:table]
      @geometry = options[:geometry]
      @srid = options[:srid]
      @columns = options[:columns]
      @selections = options[:selections]
    end
  
    def select(tile_index, scale)
      arguments = query_arguments(tile_index, scale)
      connection.exec(*arguments)
    end
  
    private
  
      def query_arguments(tile_index, scale)
    
        column_conditions = Hash.new { |hash, key| hash[key] = [] }
    
        @selections.each do |selection|
          if selection.zoom.include?(tile_index.z)
            selection.columns.each do |column|
              column_conditions[column] << selection.sql
            end
          end
        end
    
        columns = (["osm_id"] + column_conditions.map do |(column, conditions)|
          condition = conditions.map { |c| "(#{c})" }.join(" OR ")
          "CASE WHEN #{condition} THEN #{column} ELSE NULL END AS #{column}"
        end).join(", ")
    
        conditions = (["FALSE"] + @selections.map do |selection|
          if selection.zoom.include?(tile_index.z)
            "(#{selection.sql})"
          else
            nil
          end
        end.compact).join(" OR ")
    
        bounds = tile_index.bounds
    
        [<<-END]
  SELECT
    CASE
      WHEN ST_Dimension(#{@geometry}) = 0 THEN
        ST_AsGeoJSON(
          ST_Translate(
            #{@geometry},
            #{-bounds[:left]},
            #{-bounds[:top]}
          ),
          0
        )
      WHEN ST_Dimension(#{@geometry}) = 1 THEN
        ST_AsGeoJSON(
          ST_TransScale(
            ST_Intersection(
              ST_SimplifyPreserveTopology(#{@geometry}, #{bounds[:width] / scale.to_f}),
              ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, #{@srid})
            ),
            #{-bounds[:left]},
            #{-bounds[:top]},
            #{scale.to_f / (bounds[:right] - bounds[:left])},
            #{-scale.to_f / (bounds[:top] - bounds[:bottom])}
          ),
          0
        )
      WHEN ST_Dimension(#{@geometry}) = 2 THEN
        ST_AsGeoJSON(
          ST_TransScale(
            ST_Intersection(
              ST_Buffer(
                ST_SimplifyPreserveTopology(#{@geometry}, #{bounds[:width] / scale.to_f}),
                0
              ),
              ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, #{@srid})
            ),
            #{-bounds[:left]},
            #{-bounds[:top]},
            #{scale.to_f / (bounds[:right] - bounds[:left])},
            #{-scale.to_f / (bounds[:top] - bounds[:bottom])}
          ),
          0
        )
      ELSE 'EMPTY'
    END AS #{@geometry},
    #{columns}
  FROM
    #{@table}
  WHERE
    (#{conditions}) AND
    ST_Intersects(way, ST_MakeEnvelope(#{bounds[:left]}, #{bounds[:top]}, #{bounds[:right]}, #{bounds[:bottom]}, #{@srid}))
  END
      
      end
  
  end
  
end
