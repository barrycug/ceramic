require "pg"

module Cover

  class Source
  
    def initialize(table, options = {})
    
      @table = table
      @connection = options[:connection]
      @options = options
    
    end
  
    def select_rows(index, scale)
    
      # Get arguments to use to execute the query
    
      arguments = query_arguments(index, scale)
    
      # Execute the query
    
      result = @connection.exec(*arguments)
    
      # Get the types of columns
    
      types = {}
    
      result.num_fields.times do |i|
        types[result.fname(i)] = @connection.exec("SELECT format_type($1, $2)", [result.ftype(i), result.fmod(i)]).getvalue(0, 0)
      end
    
      # Process tuples and return rows
    
      # For any geometry columns that were declared, record what their GeoJSON
      # counterparts are named.
    
      geometry = @options[:geometry].map do |column, _|
        column
      end
    
      geometry_json = @options[:geometry].inject({}) do |hash, (column, _)|
        hash[column + "_geometry_json"] = column
        hash
      end
    
      # For each tuple, determine whether we should...
      # - not output it, since it is an original geometry column
      # - parse its JSON and output the resulting hash using the original
      #   geometry column's name, since it is one of our GeoJSON columns
      # - parse it as hstore and output it as a hash
      # - output it as-is
    
      result.map do |tuple|
      
        row = {}
      
        tuple.each do |column, value|
        
          if @options[:geometry].has_key?(column)
            next
          elsif geometry_json.has_key?(column)
            row[geometry_json[column]] = JSON.parse(tuple[column])
          elsif types[column] == "hstore"
            row[column] = hash_from_hstore(value)
          elsif types[column] == "integer"
            row[column] = value.to_i
          elsif types[column] == "real"
            row[column] = value.to_f
          else
            row[column] = value
          end
        
        end
      
        row
      
      end
    
    end
  
    def query_arguments(index, scale)
    
      # prepare the list of columns
    
      columns = ["*"]
    
      @options[:geometry].each do |column, column_options|
      
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
    
      if @options[:bbox]
        conditions = "WHERE #{quote(@options[:bbox])} && #{build_envelope}"
      else
        conditions = ""
      end
    
      # put the query together
    
      query = "SELECT #{columns.join(", ")} FROM #{subquery} #{conditions}"
    
      # calculate parameters
    
      bbox = index.bbox(@options[:srid])
    
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
        "srid" => @options[:srid]
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
        @options[:connection].quote_ident(column)
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
