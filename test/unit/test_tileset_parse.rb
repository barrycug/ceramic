require File.expand_path("./helper", File.dirname(__FILE__))
require "json"
require "stringio"

class TestTilesetParse < Test::Unit::TestCase
  
  def setup
    @tileset = Cover::Tileset.parse_file("./fixtures/tileset.rb")
  end
  
  def test_scale_is_set
    assert_equal 256, @tileset.scale
  end
  
  def test_query_source
    result = []
    @tileset.sources.first.query(Cover::Index.new(1, 1, 1)) do |feature|
      result << feature
    end
    
    assert_equal 42, result[0]["id"]
  end
  
end
