require "json"

class Writer
  
  def write(feature, io)
    io << feature.to_json
  end
  
end
