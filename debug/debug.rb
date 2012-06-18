require "rubygems"
require "pg"
require "yaml"
require "sinatra"
require "#{File.dirname(__FILE__)}/../lib/maker"
require "#{File.dirname(__FILE__)}/../lib/tile"

unless ENV["DATABASE"]
  puts "DATABASE environment variable must be specified"
  exit
end

if ENV["ZOOM"] =~ /(\d+)/
  ZOOM = $1
else
  ZOOM = 13
end

if ENV["CENTER"] =~ /(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?)/
  LAT = $1
  LNG = $2
else
  LAT = 37.48
  LNG = -122.44
end

CONNECTION = PG.connect(dbname: "california")
CONFIG = YAML.load(File.read("./config.yml"))
MAKER = Maker.new(CONNECTION, CONFIG)

def make_tile(z, x, y)
  time = Time.now
  tile = Tile.new(z.to_i, x.to_i, y.to_i)
  result = MAKER.render_tile(tile)
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
