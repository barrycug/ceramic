require "json"

module Cover

  class Writer
  
    def write_feature(row, io)
      
      if row["way"] == "{\"type\":\"GeometryCollection\",\"geometries\":[]}"
        return false
      end
    
      io << "{"
      io << "\"type\":\"osm\","
      io << "\"id\":#{row["osm_id"]},"
      io << "\"geometry\":#{row["way"]},"
    
      tag_members = row.inject([]) do |members, (name, value)|
        members << "\"#{name}\":#{value.to_json}" unless %w(way point osm_id).include?(name) || value.nil?
        members
      end
    
      io << "\"tags\":{"
      io << tag_members.join(",")
      io << "}"
    
      io << "}"
      
      true
    
    end
  
  end

end
