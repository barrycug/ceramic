require "json"

module Cover

  class Writer
  
    def write(feature, io)
      
      io << "{"
      
      io << "\"id\":#{feature["id"].to_json}," if feature.has_key?("id")
      io << "\"geometry\":#{feature["geometry"]}," if feature.has_key?("geometry")
      
      io << "\"properties\":{"
      
      first = true
      
      feature.each do |name, value|
        io << "," unless first
        
        unless %w(id geometry).include?(name) || value.nil?
          io << "#{name.to_s.to_json}:#{value.to_json}"
          first = false
        end
      end
      
      io << "}"
      
      io << "}"
      
    end
  
  end
  
end
