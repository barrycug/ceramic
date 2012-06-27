require "json"

module Cover
  
  class Renderer
    
    def render(rows, granularity)
    
      result = {
        "type" => "FeatureCollection",
        "granularity" => granularity,
        "features" => []
      }
    
      rows.each do |row|
        feature = row_to_feature(row)
        result["features"] << feature if feature
      end
    
      json = JSON.dump(result)
      
    end
    
    protected
    
      def row_to_feature(row)
      
        feature = {
          "type" => "Feature",
          "properties" => {}
        }
        
        # Assign the feature's geometry (from the "json" column)
      
        feature["geometry"] = JSON.parse(row["json"])
        
        # Ignore features with GeometryCollection geometries
      
        if feature["geometry"]["type"] == "GeometryCollection"
          return nil
        end
      
        # Copy columns as properties if present, ignoring the
        # GeoJSON geometry column, "json"
      
        row.each_pair do |key, value|
        
          if key != "json" && value
            feature["properties"][key] = value
          end
        
        end
      
        feature
      
      end
    
  end
  
end
