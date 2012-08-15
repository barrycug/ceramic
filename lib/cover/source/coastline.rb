require "pg"

module Cover
  module Source
    
    class Coastline
      
      attr_accessor :connection
      
      def initialize(table, options = {})
        @table = table
        @geometry_column = options[:geometry_column] || "the_geom"
        @geometry_srid = options[:geometry_srid] || 3857
        @zoom = Cover::Util.parse_zoom(options[:zoom]) if options[:zoom]
      end
      
      def select_rows(tile_index, scale)
        
        if @zoom != nil && !@zoom.include?(tile_index.z)
          return Enumerator.new { |y| }
        end
        
        query = PostGISQuery.new(
          :table => @table,
          :geometry => {
            @geometry_column => [
              "ST_Union($)",
              PostGISQuery::WRAP_POLYGON,
              "ST_SimplifyPreserveTopology($, :unit)",
              @geometry_column
            ]
          },
          :intersection_geometry_column => @geometry_column
        )
        
        bounds = tile_index.bounds
        
        parameters = {
          "scale" => [scale.to_f, "float"],
          "left" => [bounds.left, "float"],
          "top" => [bounds.top, "float"],
          "bottom" => [bounds.bottom, "float"],
          "right" => [bounds.right, "float"],
          "width" => [bounds.width, "float"],
          "height" => [bounds.height, "float"],
          "unit" => [bounds.width / scale.to_f, "float"],
          "srid" => [@geometry_srid, "int"]
        }
        
        arguments = PostGISQuery.build_exec_arguments(query, parameters)
        
        Enumerator.new do |y|
          connection.exec(*arguments) do |result|
            result.each do |row|
              y << row
            end
          end
        end
        
      end
      
    end
    
  end
  
end
