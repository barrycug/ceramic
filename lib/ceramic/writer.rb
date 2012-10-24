require "json"

module Ceramic

  class Writer
    
    # Write a feature to +io+ as a GeoJSON Feature object.
    # If present, the +"geometry"+ or +"id"+ members are written to the
    # top level of the object. Other members are written to the
    # object's +"properties"+ member.
    # @param [Hash] feature
    # @param [IO] io
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
