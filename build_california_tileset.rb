#!/usr/bin/env ruby
require "rubygems"

$LOAD_PATH << "./#{File.dirname(__FILE__)}/lib"
$LOAD_PATH << "./#{File.dirname(__FILE__)}/vendor"
require "zlib"
require "cover"
require "global_map_tiles/global_map_tiles"

# Config

require "./#{File.dirname(__FILE__)}/basic"

# Build the list of tiles

indices = []

mercator = GlobalMercator.new(256)

mminx, mminy = mercator.lat_lon_to_meters(31.9, -125.3)
mmaxx, mmaxy = mercator.lat_lon_to_meters(42.4, -113.6)

[10, 12, 14].each do |tz|

  tminx, tminy = mercator.meters_to_tile(mminx, mminy, tz)
  tmaxx, tmaxy = mercator.meters_to_tile(mmaxx, mmaxy, tz)

  (tminy..tmaxy).each do |ty|
    (tminx..tmaxx).each do |tx|
      indices << Cover::Index.new(tz, *mercator.google_tile(tx, ty, tz))
    end
  end
  
end

# Load the config

config = Basic.new

# Set up to rendering and store the files

config.setup

database = SQLite3::Database.new("california.mbtiles")
tileset = Cover::Tileset.new(database)

tileset.create_schema
tileset.set_metadata(
  name: "California Data Tiles",
  format: "js.gz"
)

# Render the tiles

indices.each_with_index do |index, i|
  puts "#{index.z}/#{index.x}/#{index.y} (#{i}/#{indices.size})"
  data = config.maker.render_tile(index)
  tileset.insert_tile(index, Zlib.deflate(data, 9))
end

# Vacuum/analyze and close databases

puts "Optimizing tileset..."

tileset.optimize

database.close

config.teardown
