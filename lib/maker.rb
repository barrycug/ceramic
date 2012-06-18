require "rubygems"
require "json"

class Maker
  
  def initialize(connection, config)
    @connection = connection
    @config = config
  end
  
  def write_tile(tile, path)
    
    result = render_tile(tile)
    
    if path == "-"
      puts result
    else
      formatted_path = path.gsub("%z", tile.z.to_s).gsub("%x", tile.x.to_s).gsub("%y", tile.y.to_s)
      FileUtils.mkdir_p(File.dirname(formatted_path))
      File.open(formatted_path, "w+") { |f| f << result }
    end
    
  end
  
  def render_tile(tile)
    
    result = {
      "granularity" => @config["granularity"] || 1000,
      "features" => []
    }
    
    @config["tables"].each do |table|
      
      arguments = case table["geometry"]
      when "point"
        point_query_arguments(tile, :columns => table["columns"])
      when "line"
        line_query_arguments(tile, :columns => table["columns"])
      when "polygon"
        polygon_query_arguments(tile, :columns => table["columns"])
      end
      
      result["features"] += find_features(arguments)
      
    end
    
    json = JSON.dump(result)
    
    if @config["callback"]
      "#{@config["callback"]}(#{json}, #{tile.z}, #{tile.x}, #{tile.y})"
    else
      json
    end
    
  end
  
  protected
  
    # "Prepare" a query for finding points within the tile (arguments
    # will be given to the PG::Connection#exec method).
  
    def point_query_arguments(tile, options = {})
      return [<<-END, [-tile.left, -tile.top, @config["granularity"].to_f / tile.width, @config["granularity"].to_f / tile.height, tile.bbox[0], tile.bbox[1], tile.bbox[2], tile.bbox[3]]]
select
  ST_AsGeoJSON(ST_TransScale(way, $1, $2, $3, $4), 0) as way
  #{(options[:columns] ? "," : "") + options[:columns].map { |c| @connection.quote_ident(c) }.join(", ")}
from
  planet_osm_point
where
  way && ST_MakeEnvelope($5, $6, $7, $8, 3857)
END
    end
    
    def line_query_arguments(tile, options = {})
      return [<<-END, [tile.bbox[0], tile.bbox[1], tile.bbox[2], tile.bbox[3], -tile.left, -tile.top, @config["granularity"].to_f / tile.width, @config["granularity"].to_f / tile.height]]
select
  ST_AsGeoJSON(
    ST_TransScale(
      ST_Intersection(
        way,
        ST_MakeEnvelope($1, $2, $3, $4, 900913)
      ),
      $5, $6, $7, $8
    ),
    0
  ) as way
  #{(options[:columns] ? "," : "") + options[:columns].map { |c| @connection.quote_ident(c) }.join(", ")}
from
  planet_osm_line
where
  way && ST_MakeEnvelope($1, $2, $3, $4, 900913)
END
    end
    
    def polygon_query_arguments(tile, options = {})
      return [<<-END, [tile.bbox[0], tile.bbox[1], tile.bbox[2], tile.bbox[3], -tile.left, -tile.top, @config["granularity"].to_f / tile.width, @config["granularity"].to_f / tile.height]]
select
  ST_AsGeoJSON(
    ST_TransScale(
      ST_ForceRHR(
        ST_Intersection(
          ST_Buffer(way, 0.0),
          ST_MakeEnvelope($1, $2, $3, $4, 900913)
        )
      ),
      $5, $6, $7, $8
    ),
    0
  ) as way
  #{(options[:columns] ? "," : "") + options[:columns].map { |c| @connection.quote_ident(c) }.join(", ")}
from
  planet_osm_polygon
where
  way && ST_MakeEnvelope($1, $2, $3, $4, 900913)
END
    end
    
    # Produce the feature's hash, which will eventually be sent to
    # JSON.dump. GeoJSON geometry should be mode available in the
    # "way" column. The result of this method may be falsy (in case
    # the row should be filtered out of the final result).
    
    def feature_from_result_row(row)
      
      feature = JSON.parse(row["way"])
      
      if feature["type"] == "GeometryCollection"
        return nil
      end
      
      # Copy columns as properties if present
      
      feature["properties"] = {}
      
      row.each_pair do |key, value|
        
        if key != "way" && value
          feature["properties"][key] = value
        end
        
      end
      
      feature
      
    end
    
    def find_features(query_arguments)
      
      features = []
      
      @connection.exec(*query_arguments) do |result|
        result.each do |row|
          feature = feature_from_result_row(row)
          features << feature if feature
        end
      end
      
      features
      
    end
  
end
