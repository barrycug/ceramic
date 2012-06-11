require "rubygems"
require "json"

class Renderer
  
  def initialize(options = {})
    
    @connection = options[:connection]
    @granularity = options[:granularity]
    @callback = options[:callback]
    
  end
  
  def render(tile)
    
    result = {
      "granularity" => @granularity,
      "features" => []
    }
    
    result["features"] += find_features(point_query_arguments(tile))
    result["features"] += find_features(line_query_arguments(tile))
    
    json = JSON.dump(result)
    
    if @callback
      "#{@callback}(#{json}, #{tile.z}, #{tile.x}, #{tile.y})"
    else
      json
    end
    
  end
  
  protected
  
    # Prepare a query for finding points within the tile (arguments
    # will be given to the PG::Connection#exec method).
  
    def point_query_arguments(tile)
      return [<<-END, [-tile.left, -tile.top, @granularity / tile.width, @granularity / tile.height, tile.bbox[0], tile.bbox[1], tile.bbox[2], tile.bbox[3]]]
select
  ST_AsGeoJSON(ST_TransScale(way, $1, $2, $3, $4)) as way, osm_id, highway, name
from
  planet_osm_point
where
  way && ST_MakeEnvelope($5, $6, $7, $8, 3857)
END
    end
    
    def line_query_arguments(tile)
      return [<<-END, [tile.bbox[0], tile.bbox[1], tile.bbox[2], tile.bbox[3], -tile.left, -tile.top, @granularity / tile.width, @granularity / tile.height]]
select
  ST_AsGeoJSON(ST_TransScale(ST_Intersection(way, ST_MakeEnvelope($1, $2, $3, $4, 900913)), $5, $6, $7, $8)) as way, osm_id, highway, name
from (
  select
    (ST_Dump(ST_Multi(ST_SimplifyPreserveTopology(ST_LineMerge(way), 1)))).geom as way, osm_id, highway, name
  from (
    select
      ST_Union(way) as way, osm_id, highway, name
    from
      planet_osm_line
    where
      way && ST_MakeEnvelope($1, $2, $3, $4, 900913)
    group by osm_id, highway, name
  ) as q
) as q
END
    end
    
    # Round coordinates (possibly multidimensional)
    
    def round_coordinates(coordinates)
      
      if coordinates.is_a?(Array)
        coordinates.map { |c| round_coordinates(c) }
      else
        coordinates.to_i
      end
      
    end
    
    # Produce the feature's hash, which will eventually be sent to
    # JSON.dump. GeoJSON geometry should be mode available in the
    # "way" column. The result of this method may be falsy (in case
    # the row should be filtered out of the final result).
    
    def feature_from_result_row(row)
      
      feature = JSON.parse(row["way"])
      
      # Filter out GeometryCollection features
      
      if feature["type"] == "GeometryCollection"
        return nil
      end
      
      # Round coordinates to integer values
      
      feature["coordinates"] = round_coordinates(feature["coordinates"])
      
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
