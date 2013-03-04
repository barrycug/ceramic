require "helper"
require "json"
require "stringio"

class CustomSource
  
  def initialize(options = {})
    @message = options[:message]
  end
  
  def query(index, options = {}, &block)
    yield({ "message" => @message })
  end
  
end

class TestTilesetBuildCustom < Test::Unit::TestCase
  
  def setup
    @tileset = Ceramic::Tileset.build do
      source CustomSource, :message => "Test"
    end
  end
  
  def test_options_passed_to_custom_source_initializer
    assert_equal "Test", @tileset.sources.first.instance_variable_get(:@message)
  end
  
  def test_query_custom_source
    result = []
    @tileset.sources.first.query(Ceramic::Index.new(1, 1, 1)) do |feature|
      result << feature
    end
    
    assert_equal "Test", result[0]["message"]
  end
  
end
