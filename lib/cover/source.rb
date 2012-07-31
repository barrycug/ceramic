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
      
      # puts arguments[0].gsub(/\$(\d+)/) { |i| "(#{arguments[1][i.to_i - 1]})" }
      
      # puts arguments[0]
      # puts arguments[1].inspect
      
      result = @connection.exec(*arguments)
      rows = process_result(result, size * size)
      result.clear
      
      rows
      
    end
    
    def metatile_query_arguments(index, scale, size)
      
      # Prepare the list of columns to select. Geometry columns
      # are named <column name>_geometry_json, and include simplification,
      # intersection, etc.
      
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
      
      # Replace the !bbox! placeholder in the table/subquery with the area
      # of the entire metatile. Since we use this subquery once in the "metatile"
      # subquery, we want it to catch everything in the metatile.
  
      subquery = @table.gsub("!bbox!", "ST_MakeEnvelope(:left, :top, :left + (:size * :width), :top - (:size * :height), :srid)")
      
      # Build the query. We select the data in the metatile using the && operator
      # for intersection, and then select the contents of each tile from that.
      
      query = <<-END
WITH
  metatile AS (
    SELECT *
    FROM #{subquery}
    WHERE #{quote(@bbox_column)} && ST_MakeEnvelope(:left, :top, :left + (:size * :width), :top - (:size * :height), :srid)
  ),
  
  tiles AS (
    SELECT
      (x * :size) + y AS __index,
      ST_MakeEnvelope(
        :left + (x * :width),
        :top - (y * :height),
        :left + ((x+1) * :width),
        :top - ((y+1) * :height),
        :srid
      ) as __bbox,
      -:left - (x * :width) AS __translate_x,
      -:top + (y * :height) AS __translate_y,
      :scale / :width AS __scale_x,
      -:scale / :height AS __scale_y
    FROM
      (SELECT generate_series(0, :size - 1)) as x(x)
      CROSS JOIN
      (SELECT generate_series(0, :size - 1)) as y(y)
  )

SELECT
  #{columns.join(", ")}
FROM
  metatile INNER JOIN tiles
  ON ST_Intersects(#{quote(@bbox_column)}, tiles.__bbox)
END
    
      # Given the index's bbox, build query arguments.
    
      bbox = index.bbox(@geometry_srid)
    
      parameters = {
        "scale" => [scale.to_f, "float"],
        "left" => [bbox[:left], "float"],
        "top" => [bbox[:top], "float"],
        "width" => [bbox[:width], "float"],
        "height" => [bbox[:height], "float"],
        "unit" => [bbox[:width] / scale.to_f, "float"],
        "srid" => [@geometry_srid, "int"],
        "size" => [size, "int"]
      }
  
      build_query_arguments(query, parameters)
      
    end
  
    protected
    
      def process_result(result, length)
        
        geometry_json = @geometry_column_options.inject({}) do |hash, (column, _)|
          hash[column + "_geometry_json"] = column
          hash
        end
        
        tiles = Array.new(length) { [] }
    
        result.each do |tuple|
          row = {}
          index = nil
      
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
            elsif column == "__index"
              index = value.to_i
            elsif column == "__bbox" || column == "__translate_x" || column == "__translate_y" || column == "__scale_x" || column == "__scale_y"
            else
              row[column] = value
            end
          end
          
          tiles[index] << row
        end
        
        tiles
        
      end
  
      def build_query_arguments(query, named)
        result = query.dup
        numbered = []
  
        named.each do |name, (value, type)|
          if result.gsub!(":#{name}", "$#{numbered.size + 1}::#{type}")
            numbered << value
          end
        end
  
        [result, numbered]
      end
  
      def build_point_geometry_column(name, options = {})
        <<-END
  ST_AsGeoJSON(
    ST_TransScale(
      #{name},
      tiles.__translate_x,
      tiles.__translate_y,
      tiles.__scale_x,
      tiles.__scale_y
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
        tiles.__bbox
      ),
      tiles.__translate_x,
      tiles.__translate_y,
      tiles.__scale_x,
      tiles.__scale_y
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
          tiles.__bbox
        )
      ),
      tiles.__translate_x,
      tiles.__translate_y,
      tiles.__scale_x,
      tiles.__scale_y
    ),
    0
  ) AS #{quote(name + "_geometry_json")}
  END
      end
    
      def build_simplify(name, simplify)
        if simplify && simplify > 0
          "ST_SimplifyPreserveTopology(#{quote(name)}, :unit * #{simplify})"
        else
          quote(name)
        end
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
