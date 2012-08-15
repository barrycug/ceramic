$LOAD_PATH << "#{File.dirname(__FILE__)}/../vendor"

require "cover/util"
require "cover/postgis_query"
require "cover/maker"
require "cover/tile_index"
require "cover/source"
require "cover/viewer"

module Cover
  
  # For use with config files only. Set Cover.config to an object
  # which responds to #maker, and optionally #setup and #teardown
  # so that script/view and script/tile will pick up the config.
  #
  # This is not intended to be accessed by classes under Cover::.
  
  def self.config
    @@config
  end
  
  def self.config=(config)
    @@config = config
  end
  
end
