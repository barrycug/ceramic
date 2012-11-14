require "pg"

module Ceramic
  module Source
    
    class PostGIS
      
      class Table
        
        attr_accessor :table_expression
        attr_accessor :geometry_column
        attr_accessor :geometry_srid
        attr_accessor :zoom
        
        # @param [String] table_expression An SQL table expression, which must
        #   select at least a geometry column. The column's name must match
        #   the :geometry_column option and the column's SRID must match the
        #   :geometry_srid option. This can be a subquery (which must have an
        #   alias), or the name of a table or view. For example:
        #
        #     planet_osm_point
        #     
        #     planet_osm_line_z10
        #     
        #     (SELECT osm_id, way, tags -> 'height' AS height
        #      FROM planet_osm_polygon
        #      WHERE building IS NOT NULL AND building <> 'no') AS buildings
        #     
        #     (SELECT geometry FROM transport_points) AS transport
        #
        #   +table_expression+ may also include placeholders, which will be
        #   substituted before querying the database:
        #
        #   - :scale &mdash; The +scale+ option, as passed to {#query}
        #   - :unit &mdash; The size of one unit in the tile's coordinate system, or the visible width in intersection SRS units divided by the scale.
        #   - :area &mdash; The area of the tile in intersection SRS units.
        #   - :srid &mdash; The SRID of the intersection SRS.
        #   - :view_left, :view_top, :view_bottom, :view_right, :view_width, :view_height &mdash; The visible bounds of the tile in intersection SRS units.
        #   - :intersect_left, :intersect_top, :intersect_bottom, :intersect_right, :intersect_width, :intersect_height &mdash; The bounds of the intersection area in intersection SRS units.
        #
        # @option options [String] :geometry_column ("way") The name of the geometry column
        # @option options [Integer] :geometry_srid (900913) The SRID of the geometry column
        # @option options [String] :zoom (0..Infinity) A zoom specifier, determining the
        #   zoom levels at which the table is consulted (See {Ceramic::Util.parse_zoom})
        
        def initialize(table_expression, options = {})
          @table_expression = table_expression
          
          if options.has_key?(:geometry_column)
            @geometry_column = options[:geometry_column]
          else
            @geometry_column = "way"
          end
          
          if options.has_key?(:geometry_srid)
            @geometry_srid = options[:geometry_srid]
          else
            @geometry_srid = 900913
          end
          
          if options.has_key?(:zoom)
            @zoom = Ceramic::Util.parse_zoom(options[:zoom])
          else
            @zoom = 0..1.0/0
          end
        end
        
      end
      
      # An array of {PostGIS::Table} instances to consult.
      # @return [Array<PostGIS::Table>]
      attr_accessor :tables
      
      # Connection hash or string passed to +PG.connect+.
      # @return [Hash, String]
      attr_accessor :connection_info
      
      def initialize
        @tables = []
      end
      
      # Set up this source.
      # Connects to the Postgres database specified by +connection_info+.
      def setup
        @connection = PG.connect(connection_info)
        @column_types_cache = {}
      end
      
      # Tear down this source.
      # Closes the database connection.
      def teardown
        @connection.close
      end
      
      # Query each table specified by the objects in +tables+, and yield each feature in the result.
      # Typecasting is done for integer, real, and hstore types.
      # @yield [Hash] each feature contained in the bounding box of +index+
      # @param [Ceramic::Index] index
      # @option options [Integer] scale See {Ceramic::Tileset#scale}
      # @option options [Float] margin See {Ceramic::Tileset#margin}
      # @option options [:tile, :latlon] coordinates See {Ceramic::Tileset#coordinates}
      
      def query(index, options = {}, &block)
        
        unless options.has_key?(:coordinates)
          raise ArgumentError, ":coordinates option must be present"
        end
        
        unless options.has_key?(:margin)
          raise ArgumentError, ":margin option must be present"
        end
        
        unless [:tile, :latlon].include?(options[:coordinates])
          raise ArgumentError, ":coordinates option must be :tile or :latlon"
        end
        
        if options[:coordinates] == :tile && !options.has_key?(:scale)
          raise ArgumentError, ":scale option must be present if :coordinates option is :tile"
        end
        
        parameters = build_parameters(index, options)
        
        tables.each do |table|
          
          if table.zoom.include?(index.z)
            arguments = build_exec_arguments(build_query(table, options), parameters)
            
            @connection.exec(*arguments) do |result|
              column_types = format_column_types(result)
              
              result.each do |row|
                yield build_feature(row, table, column_types)
              end
            end
          end
          
        end
        
      end
      
      private
      
        def build_parameters(index, options = {})
          
          bounds = index.bounds
          scale = options[:scale]
          margin = options[:margin]
          
          {
            "scale" => [scale, "float"],
            "unit" => [bounds.width / scale, "float"],
            "area" => [bounds.width * bounds.height, "float"],
          
            "view_left" => [bounds.left, "float"],
            "view_top" => [bounds.top, "float"],
            "view_bottom" => [bounds.bottom, "float"],
            "view_right" => [bounds.right, "float"],
            "view_width" => [bounds.width, "float"],
            "view_height" => [bounds.height, "float"],
          
            "intersect_left" => [bounds.left - (bounds.width * margin), "float"],
            "intersect_top" => [bounds.top + (bounds.height * margin), "float"],
            "intersect_bottom" => [bounds.bottom - (bounds.height * margin), "float"],
            "intersect_right" => [bounds.right + (bounds.height * margin), "float"],
            "intersect_width" => [bounds.width + (bounds.width * margin * 2), "float"],
            "intersect_height" => [bounds.height + (bounds.height * margin * 2), "float"]
          }
          
        end
        
        def build_query(table, options = {})
          
          wrap_expressions = []
          
          wrap_expressions << "SELECT $ AS geometry, * FROM #{table.table_expression} WHERE #{table.geometry_column} && ST_Transform(ST_MakeEnvelope(:intersect_left, :intersect_top, :intersect_right, :intersect_bottom, 3857), #{table.geometry_srid})"
          
          if options[:coordinates] == :tile
            wrap_expressions << "ST_AsGeoJSON($, 0)"
          else
            wrap_expressions << "ST_AsGeoJSON($, 7)"
          end
          
          if options[:coordinates] == :tile
            wrap_expressions << "ST_TransScale($, -:view_left, -:view_top, :scale / :view_width, -:scale / :view_height)"
          end
          
          wrap_expressions << "ST_ForceRHR($)"
          
          if options[:coordinates] == :tile
            wrap_expressions << "ST_Intersection($, ST_MakeEnvelope(:intersect_left, :intersect_top, :intersect_right, :intersect_bottom, 3857))"
          else
            wrap_expressions << "ST_Intersection($, ST_Transform(ST_MakeEnvelope(:intersect_left, :intersect_top, :intersect_right, :intersect_bottom, 3857), 4326))"
          end
          
          wrap_expressions << "CASE ST_Dimension(#{table.geometry_column}) WHEN 2 THEN ST_Buffer($, 0) ELSE $ END"
          
          if options[:coordinates] == :tile
            wrap_expressions << "ST_Transform(#{table.geometry_column}, 3857)"
          else
            wrap_expressions << "ST_Transform(#{table.geometry_column}, 4326)"
          end
          
          compose_wrap_expressions(wrap_expressions)
          
        end
        
        def compose_wrap_expressions(wrap_expressions)
          if wrap_expressions.first.include?("$")
            wrap_expressions.first.gsub("$", compose_wrap_expressions(wrap_expressions[1..-1]))
          else
            wrap_expressions.first
          end
        end
        
        def build_exec_arguments(query, parameters)
          result = query.to_s
          numbered = []

          parameters.each do |name, (value, type)|
            if result.gsub!(":#{name}", "$#{numbered.size + 1}::#{type}")
              numbered << value
            end
          end

          [result, numbered]
        end
        
        def build_feature(row, table, column_types)
          result = {}
          
          row.each do |column, value|
            next if column == table.geometry_column
            result[column] = type_cast(value, column_types[column])
          end
          
          result
        end
        
        def format_column_types(result)
          types = {}
          
          (0...result.nfields).each do |fnum|
            fname = result.fname(fnum)
            pair = [result.ftype(fnum), result.fmod(fnum)]
            
            unless @column_types_cache.has_key?(pair)
              @column_types_cache[pair] = @connection.exec("SELECT format_type($1, $2)", [result.ftype(fnum), result.fmod(fnum)]).getvalue(0, 0)
            end
            
            types[fname] = @column_types_cache[pair]
          end
          
          types
        end
        
        def type_cast(value, type)
          case type
          when "integer" then value.to_i
          when "real"    then value.to_f
          when "hstore"  then parse_hstore(value)
          else value
          end
        end
        
        #:nodoc:
        
        # Adapted from http://engageis.github.com/activerecord-postgres-hstore/
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
        
        HSTORE_QUOTED_STRING = /"[^"\\]*(?:\\.[^"\\]*)*"/
        HSTORE_UNQUOTED_STRING = /[^\s=,][^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
        HSTORE_STRING = /(#{HSTORE_QUOTED_STRING}|#{HSTORE_UNQUOTED_STRING})/
        HSTORE_PAIR = /#{HSTORE_STRING}\s*=>\s*#{HSTORE_STRING}/
        
        def parse_hstore(string)
          token_pairs = (string.scan(HSTORE_PAIR)).map { |k,v| [k,v =~ /^NULL$/i ? nil : v] }
          token_pairs = token_pairs.map { |k,v|
            [k,v].map { |t|
              case t
              when nil then t
              when /\A"(.*)"\Z/m then $1.gsub(/\\(.)/, '\1')
              else t.gsub(/\\(.)/, '\1')
              end
            }
          }
          Hash[token_pairs]
        end
      
    end
    
  end
end
