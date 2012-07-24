require "pg"

module Cover

  class Source
  
    def initialize(table, options = {})
    
      @table = table
      
      @connection = options[:connection]
      @geometry_column_options = options[:geometry]
      @type_conversions = options[:convert] || {}
      @bbox_column = options[:bbox]
      @geometry_srid = options[:srid]
    
    end
    
    def select_metatile(index, scale, size)
    
      arguments = metatile_query_arguments(index, scale, size)
      
      result = @connection.exec(*arguments)
      
      geometry_json = @geometry_column_options.inject({}) do |hash, (column, _)|
        hash[column + "_geometry_json"] = column
        hash
      end
    
      tiles = Array.new(size * size) { [] }
    
      result.each do |tuple|
      
        row = {}
      
        tuple.each do |column, value|
        
          if column == "grid_index" || column == "grid_bbox"
            next
          elsif @geometry_column_options.has_key?(column)
            next
          elsif geometry_json.has_key?(column)
            row[geometry_json[column]] = JSON.parse(tuple[column])
          elsif @type_conversions[column] == :hstore
            row[column] = hash_from_hstore(value)
          elsif @type_conversions[column] == :integer
            row[column] = value.to_i
          elsif @type_conversions[column] == :real
            row[column] = value.to_f
          else
            row[column] = value
          end
        
        end
      
        tiles[tuple["grid_index"].to_i] << row
      
      end
      
      result.clear
      
      tiles
      
    end
    
    def metatile_query_arguments(index, scale, size)
    
      columns = ["*"]
    
      @geometry_column_options.each do |column, column_options|
      
        case column_options[:type]
        when :point
          columns << build_point_geometry_column(column, column_options)
        when :line
          columns << build_line_geometry_column(column, column_options)
        when :polygon
          columns << build_polygon_geometry_column(column, column_options)
        end
      
      end
      
      metatile_envelope = <<-END
ST_MakeEnvelope(
  :left::float,
  :top::float,
  :left::float + (:size::int * :width::float),
  :top::float + (:size::int * :height::float),
  :srid::int
)
END
      
      subquery = @table.gsub("!bbox!", metatile_envelope)
      
      query = <<-END
WITH
  metatile AS (
    SELECT * FROM #{subquery}
    WHERE
      ST_Intersects(
        #{quote(@bbox_column)},
        #{metatile_envelope}
      )
  ),
  grid AS (
    SELECT
      (grid_y + (grid_x * :size::int)) as grid_index,
      ST_MakeEnvelope(
        :left::float + (grid_x * :width::float),
        :top::float + (grid_y * :height::float),
        :left::float + ((grid_x + 1) * :width::float),
        :top::float + ((grid_y + 1) * :height::float),
        :srid::int
      ) AS grid_bbox
    FROM
      (SELECT generate_series(0, :size::int - 1)) AS x(grid_x)
      CROSS JOIN
      (SELECT generate_series(0, :size::int - 1)) AS y(grid_y)
  )
SELECT
  #{columns.join(", ")}
FROM
  metatile INNER JOIN grid
  ON ST_Intersects(#{quote(@bbox_column)}, grid_bbox)
END
      
      bbox = index.bbox(@geometry_srid)
    
      parameters = {
        "translate_x" => -bbox[:left],
        "translate_y" => -bbox[:top],
        "scale_x" => scale.to_f / bbox[:width],
        "scale_y" => scale.to_f / bbox[:height],
        "left" => bbox[:left],
        "top" => bbox[:top],
        "right" => bbox[:right],
        "bottom" => bbox[:bottom],
        "width" => bbox[:right] - bbox[:left],
        "height" => bbox[:bottom] - bbox[:top],
        "unit" => bbox[:width] / scale.to_f,
        "srid" => @geometry_srid,
        "size" => size
      }
    
      build_query_arguments(query, parameters)
      
    end
  
    def select_rows(index, scale)
    
      # Get arguments to use to execute the query
    
      arguments = query_arguments(index, scale)
    
      # Execute the query
    
      result = @connection.exec(*arguments)
    
      # Process tuples and return rows
    
      # For any geometry columns that were declared, record what their GeoJSON
      # counterparts are named.
    
      geometry_json = @geometry_column_options.inject({}) do |hash, (column, _)|
        hash[column + "_geometry_json"] = column
        hash
      end
    
      # For each tuple, determine whether we should...
      # - not output it, since it is an original geometry column
      # - parse its JSON and output the resulting hash using the original
      #   geometry column's name, since it is one of our GeoJSON columns
      # - parse it as hstore and output it as a hash
      # - parse it as an integer and output as an integer
      # - output it as-is
    
      rows = result.map do |tuple|
      
        row = {}
      
        tuple.each do |column, value|
        
          if @geometry_column_options.has_key?(column)
            next
          elsif geometry_json.has_key?(column)
            row[geometry_json[column]] = JSON.parse(tuple[column])
          elsif @type_conversions[column] == :hstore
            row[column] = hash_from_hstore(value)
          elsif @type_conversions[column] == :integer
            row[column] = value.to_i
          elsif @type_conversions[column] == :real
            row[column] = value.to_f
          else
            row[column] = value
          end
        
        end
      
        row
      
      end
      
      # Clear the result
      
      result.clear
      
      rows
    
    end
  
    def query_arguments(index, scale)
    
      # prepare the list of columns
    
      columns = ["*"]
    
      @geometry_column_options.each do |column, column_options|
      
        case column_options[:type]
        when :point
          columns << build_point_geometry_column(column, column_options)
        when :line
          columns << build_line_geometry_column(column, column_options)
        when :polygon
          columns << build_polygon_geometry_column(column, column_options)
        end
      
      end
    
      # set the subquery, replacing the !bbox! macro with a real envelope
    
      subquery = @table.gsub("!bbox!", build_envelope)
    
      # set intersects condition if the bbox option is specified
    
      if @bbox_column
        conditions = "WHERE #{quote(@bbox_column)} && #{build_envelope}"
      else
        conditions = ""
      end
    
      # put the query together
    
      query = "SELECT #{columns.join(", ")} FROM #{subquery} #{conditions}"
    
      # calculate parameters
    
      bbox = index.bbox(@geometry_srid)
    
      parameters = {
        "translate_x" => -bbox[:left],
        "translate_y" => -bbox[:top],
        "scale_x" => scale.to_f / bbox[:width],
        "scale_y" => scale.to_f / bbox[:height],
        "left" => bbox[:left],
        "top" => bbox[:top],
        "right" => bbox[:right],
        "bottom" => bbox[:bottom],
        "unit" => bbox[:width] / scale.to_f,
        "srid" => @geometry_srid
      }
    
      # build [query, parameters] from the query and named parameters
  
      build_query_arguments(query, parameters)
  
    end
  
    protected
  
      def build_query_arguments(query, named)
        result = query.dup
        numbered = []
  
        named.each do |name, value|
          if result.gsub!(":#{name}", "$#{numbered.size + 1}")
            numbered << value
          end
        end
  
        [result, numbered]
      end
  
      def build_point_geometry_column(name, options = {})
        <<-END
  ST_AsGeoJSON(
    ST_TransScale(
      #{quote(name)},
      :translate_x::float,
      :translate_y::float,
      :scale_x::float,
      :scale_y::float
    ),
    0
  ) AS #{quote(name + "_geometry_json")}
  END
      end
    
      def build_line_geometry_column(name, options = {})
        <<-END
  ST_AsGeoJSON(
    ST_TransScale(
      ST_Intersection(
        #{build_simplify(name, options[:simplify])},
        #{build_envelope}
      ),
      :translate_x::float,
      :translate_y::float,
      :scale_x::float,
      :scale_y::float
    ),
    0
  ) AS #{quote(name + "_geometry_json")}
  END
      end
    
      def build_polygon_geometry_column(name, options = {})
        <<-END
  ST_AsGeoJSON(
    ST_TransScale(
      ST_ForceRHR(
        ST_Intersection(
          ST_Buffer(
            #{build_simplify(name, options[:simplify])},
            0
          ),
          #{build_envelope}
        )
      ),
      :translate_x::float,
      :translate_y::float,
      :scale_x::float,
      :scale_y::float
    ),
    0
  ) AS #{quote(name + "_geometry_json")}
  END
      end
    
      def build_simplify(name, simplify)
        if simplify && simplify > 0
          "ST_SimplifyPreserveTopology(#{quote(name)}, :unit::float * #{simplify}::float)"
        else
          quote(name)
        end
      end
    
      def build_envelope
        "ST_MakeEnvelope(:left::float, :top::float, :right::float, :bottom::float, :srid::int)"
      end
    
      def quote(column)
        @connection.quote_ident(column)
      end
    
      # Adapted from activerecord-postgres-hstore
      #
      # Copyright (c) 2009 Juan Maiz
      # 
      # Permission is hereby granted, free of charge, to any person obtaining
      # a copy of this software and associated documentation files (the
      # "Software"), to deal in the Software without restriction, including
      # without limitation the rights to use, copy, modify, merge, publish,
      # distribute, sublicense, and/or sell copies of the Software, and to
      # permit persons to whom the Software is furnished to do so, subject to
      # the following conditions:
      # 
      # The above copyright notice and this permission notice shall be
      # included in all copies or substantial portions of the Software.
      # 
      # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
      # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
      # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
      # LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
      # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
      # WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    
      def hash_from_hstore(hstore_string)
        quoted_string = /"[^"\\]*(?:\\.[^"\\]*)*"/
        unquoted_string = /[^\s=,][^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
        string = /(#{quoted_string}|#{unquoted_string})/
        hstore_pair = /#{string}\s*=>\s*#{string}/
      
        token_pairs = (hstore_string.scan(hstore_pair)).map { |k,v| [k,v =~ /^NULL$/i ? nil : v] }
        token_pairs = token_pairs.map { |k,v|
          [k,v].map { |t| 
            case t
            when nil then t
            when /^"(.*)"$/ then $1.gsub(/\\(.)/, '\1')
            else t.gsub(/\\(.)/, '\1')
            end
          }
        }
        Hash[token_pairs]
      end
  
  end

end
