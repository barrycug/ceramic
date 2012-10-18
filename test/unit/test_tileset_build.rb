require "helper"
require "json"
require "stringio"

class TestTilesetBuild < Test::Unit::TestCase
  
  def setup
    @tileset = Cover::Tileset.build do
      scale 256
      source(:proc) { |index| [ { "id" => 42 }, { "id" => 13 } ] }
    end
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
  
  def test_write_tile
    str = StringIO.new("")
    @tileset.write(Cover::Index.new(1, 1, 1), str)
    result = JSON.parse(str.string)
    
    assert_equal 256, result["scale"]
    assert_equal 2, result["features"].size
    assert_equal 42, result["features"][0]["id"]
    assert_equal 13, result["features"][1]["id"]
  end
  
end
