require File.expand_path('../helper', __FILE__)
require "json"
require "stringio"

class TestWriter < Test::Unit::TestCase
  
  def write_feature(feature)
    writer = Cover::Writer.new
    str = StringIO.new("")
    writer.write(feature, str)
    JSON.parse(str.string)
  end
  
  def test_id_written_at_top_level
    result = write_feature({ "id" => 123 })
    
    assert_equal 123, result["id"]
  end
  
  def test_geometry_passthrough
    result = write_feature({ "geometry" => "{\"type\":\"Point\",\"coordinates\":[128,128]}" })
    
    assert_equal "Point", result["geometry"]["type"]
    assert_equal [128, 128], result["geometry"]["coordinates"]
  end
  
  def test_properties
    result = write_feature({ "id" => 123, "highway" => "road" })
    
    assert_equal 123, result["id"]
    assert_equal "road", result["properties"]["highway"]
  end
  
end
  