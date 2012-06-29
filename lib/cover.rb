require "cover/maker"
require "cover/renderer"
require "cover/tileset"
require "cover/sources"
require "cover/index"

module Cover
  
  def self.config=(object)
    @@config = object
  end
  
  def self.config
    @@config
  end
  
end
