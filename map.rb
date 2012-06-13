require "rubygems"
require "sinatra"
require "pg"
require "#{File.dirname(__FILE__)}/tile"
require "#{File.dirname(__FILE__)}/renderer"

CONNECTION = PG.connect(dbname: "gis")

RENDERER = Renderer.new({
  connection: CONNECTION,
  granularity: 1000,
  callback: "tileData",
  columns: {
    point: ["osm_id"],
    line: ["osm_id"],
    polygon: ["osm_id"]
  }
})

def make_tile(z, x, y)
  
  time = Time.now
  
  tile = Tile.new(z.to_i, x.to_i, y.to_i)
  result = RENDERER.render(tile)
  
  puts "tile = #{z}/#{x}/#{y}, bytes = #{result.bytesize}, time = #{Time.now - time}s"
  
  result
  
end

get "/:z/:x/:y" do
  content_type :js
  make_tile(params[:z], params[:x], params[:y])
end

get "/" do
  erb :index
end
