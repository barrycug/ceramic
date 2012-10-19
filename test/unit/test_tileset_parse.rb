require "helper"
require "json"
require "stringio"

class TestTilesetParse < Test::Unit::TestCase
  
  def setup
    @tileset = Ceramic::Tileset.parse_file(File.dirname(__FILE__) + "/fixtures/tileset.rb")
  end
  
  def test_scale_is_set
    assert_equal 256, @tileset.scale
  end
  
  def test_query_source
    result = []
    @tileset.sources.first.query(Ceramic::Index.new(1, 1, 1)) do |feature|
      result << feature
    end
    
    assert_equal 42, result[0]["id"]
  end
  
end
