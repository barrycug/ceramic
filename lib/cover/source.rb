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
      rows = process_result(result, size * size)
      result.clear
      
      rows
      
    end
    
    def metatile_query_arguments(index, scale, size)
      
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
      
      columns << "0 as tile_index"
    
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
        "translate_x" => [-bbox[:left], "float"],
        "translate_y" => [-bbox[:top], "float"],
        "scale_x" => [scale.to_f / bbox[:width], "float"],
        "scale_y" => [scale.to_f / -bbox[:height], "float"],
        "left" => [bbox[:left], "float"],
        "top" => [bbox[:top], "float"],
        "right" => [bbox[:right], "float"],
        "bottom" => [bbox[:bottom], "float"],
        "width" => [bbox[:width], "float"],
        "height" => [bbox[:height], "float"],
        "unit" => [bbox[:width] / scale.to_f, "float"],
        "srid" => [@geometry_srid, "int"]
      }
    
      # build [query, parameters] from the query and named parameters
  
      build_query_arguments(query, parameters)
      
    end
  
    def select_rows(index, scale)
      
      arguments = query_arguments(index, scale)
      result = @connection.exec(*arguments)
      rows = process_result(result, 1)[0]
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
        "translate_x" => [-bbox[:left], "float"],
        "translate_y" => [-bbox[:top], "float"],
        "scale_x" => [scale.to_f / bbox[:width], "float"],
        "scale_y" => [scale.to_f / -bbox[:height], "float"],
        "left" => [bbox[:left], "float"],
        "top" => [bbox[:top], "float"],
        "right" => [bbox[:right], "float"],
        "bottom" => [bbox[:bottom], "float"],
        "width" => [bbox[:width], "float"],
        "height" => [bbox[:height], "float"],
        "unit" => [bbox[:width] / scale.to_f, "float"],
        "srid" => [@geometry_srid, "int"]
      }
    
      # build [query, parameters] from the query and named parameters
  
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
          index = 0
      
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
            elsif column == "tile_index"
              index = value.to_i
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
      #{quote(name)},
      :translate_x,
      :translate_y,
      :scale_x,
      :scale_y
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
      :translate_x,
      :translate_y,
      :scale_x,
      :scale_y
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
      :translate_x,
      :translate_y,
      :scale_x,
      :scale_y
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
    
      def build_envelope
        "ST_MakeEnvelope(:left, :top, :right, :bottom, :srid)"
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
