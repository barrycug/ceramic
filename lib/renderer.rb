require "json"

class Renderer
  
  def initialize(config)
    @config = config
  end
  
  # Return output, given an index and a block which collects "rows",
  # as would be returned from the database. Rows must be a hash with
  # a GeoJSON "geometry" member.
  #
  # This routine yields an object which will respond to the "<<" method
  # to collect rows, but the object will not necessarily be an array.
  
  def output(index, &block)
    
    rows = []
    yield rows
    
    result = {
      "type" => "FeatureCollection",
      "granularity" => @config["granularity"],
      "features" => []
    }
    
    rows.each do |row|
      feature = row_to_feature(row)
      result["features"] << feature if feature
    end
    
    json = JSON.dump(result)
    
    if @config["callback"]
      "#{@config["callback"]}(#{json}, #{index.z}, #{index.x}, #{index.y})"
    else
      json
    end
    
  end
  
  protected
  
    def row_to_feature(row)
      
      feature = {
        "type" => "Feature",
        "properties" => {}
      }
      
      feature["geometry"] = JSON.parse(row["geometry"])
      
      if feature["geometry"]["type"] == "GeometryCollection"
        return nil
      end
      
      # Copy columns as properties if present
      
      row.each_pair do |key, value|
        
        if key != "geometry" && value
          feature["properties"][key] = value
        end
        
      end
      
      feature
      
    end
  
end
