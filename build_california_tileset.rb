#!/usr/bin/env ruby
require "rubygems"

$LOAD_PATH << "./#{File.dirname(__FILE__)}/lib"
$LOAD_PATH << "./#{File.dirname(__FILE__)}/vendor"
require "cover"
require "global_map_tiles/global_map_tiles"

# Build the list of tiles

indices = []

mercator = GlobalMercator.new(256)

mminx, mminy = mercator.lat_lon_to_meters(37.22, -123.07)
mmaxx, mmaxy = mercator.lat_lon_to_meters(38.88, -121.11)

[10, 12, 14].each do |tz|

  tminx, tminy = mercator.meters_to_tile(mminx, mminy, tz)
  tmaxx, tmaxy = mercator.meters_to_tile(mmaxx, mmaxy, tz)

  (tminy..tmaxy).each do |ty|
    (tminx..tmaxx).each do |tx|
      indices << Cover::Index.new(tz, *mercator.google_tile(tx, ty, tz))
    end
  end
  
end

# Load the config file

require File.expand_path("basic.rb")

if Cover.config == nil
  puts "Configuration file did not set Cover.config"
  exit
end

# Set up to rendering and store the files

Cover.config.setup

database = SQLite3::Database.new("california.mbtiles")
tileset = Cover::Tileset.new(database)

tileset.create_schema
tileset.set_metadata(
  name: "California Data Tiles",
  format: "js"
)

# Render the tiles

indices.each_with_index do |index, i|
  puts "#{index.z}/#{index.x}/#{index.y} (#{i}/#{indices.size})"
  tileset.insert_tile(index, Cover.config.maker.render_tile(index))
end

# Vacuum/analyze and close databases

puts "Optimizing tileset..."

tileset.optimize

database.close

Cover.config.teardown
