require "json"

module Ceramic

  class Writer
  
    def write(feature, io)
      
      io << "{"
      
      io << "\"type\":\"Feature\","
      io << "\"id\":#{feature["id"].to_json}," if feature.has_key?("id")
      io << "\"geometry\":#{feature["geometry"]}," if feature.has_key?("geometry")
      
      io << "\"properties\":{"
      
      first = true
      
      feature.each do |name, value|
        unless %w(id geometry).include?(name) || value.nil?
          io << "," unless first
          io << "#{name.to_s.to_json}:#{value.to_json}"
          first = false
        end
      end
      
      io << "}"
      
      io << "}"
      
    end
  
  end
  
end
