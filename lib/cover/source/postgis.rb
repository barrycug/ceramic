require "pg"

module Cover
  module Source
    
    class PostGIS
      
      class Table
        
        attr_accessor :table_expression
        attr_accessor :geometry_column
        attr_accessor :geometry_srid
        attr_accessor :zoom
        
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
            @zoom = Cover::Util.parse_zoom(options[:zoom])
          else
            @zoom = 0..1.0/0
          end
        end
        
      end
      
      attr_accessor :tables
      attr_accessor :connection_info
      
      def initialize
        @tables = []
      end
      
      def setup
        @connection = PG.connect(connection_info)
        @column_types_cache = {}
      end
      
      def teardown
        @connection.close
      end
      
      def query(index, options = {}, &block)
        parameters = build_parameters(index, options)
        
        tables.each do |table|
          
          if table.zoom.include?(index.z)
            arguments = build_exec_arguments(build_query(table), parameters)
            
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
        
        def build_query(table)
          <<-END
SELECT
  ST_AsGeoJSON(
    ST_TransScale(
      CASE ST_Dimension(#{table.geometry_column})
        WHEN 1 THEN
          ST_Intersection(
            ST_Transform(#{table.geometry_column}, 3857),
            ST_MakeEnvelope(:intersect_left, :intersect_top, :intersect_right, :intersect_bottom, 3857)
          )
        WHEN 2 THEN
          ST_ForceRHR(
            ST_Intersection(
              ST_Buffer(ST_Transform(#{table.geometry_column}, 3857), 0),
              ST_MakeEnvelope(:intersect_left, :intersect_top, :intersect_right, :intersect_bottom, 3857)
            )
          )
        ELSE
          ST_Transform(#{table.geometry_column}, 3857)
      END,
      -:view_left, -:view_top, :scale / :view_width, -:scale / :view_height
    ),
    0
  ) AS geometry,
  *
FROM
  #{table.table_expression}
WHERE
  #{table.geometry_column} && ST_Transform(ST_MakeEnvelope(:intersect_left, :intersect_top, :intersect_right, :intersect_bottom, 3857), #{table.geometry_srid})
END
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
          else value
          end
        end
      
    end
    
  end
end
