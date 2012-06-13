require "rubygems"
require "pg"
require "#{File.dirname(__FILE__)}/tile"
require "#{File.dirname(__FILE__)}/renderer"

connection = PG.connect(dbname: "gis")

renderer = Renderer.new({
  connection: connection,
  granularity: 1000,
  columns: {
    point: ["access", "addr:housename", "addr:housenumber", "addr:interpolation", "admin_level", "aerialway", "aeroway", "amenity", "area", "barrier", "bicycle", "brand", "bridge", "boundary", "building", "capital", "construction", "covered", "culvert", "cutting", "denomination", "disused", "ele", "embankment", "foot", "generator:source", "harbour", "highway", "historic", "horse", "intermittent", "junction", "landuse", "layer", "leisure", "lock", "man_made", "military", "motorcar", "name", "natural", "oneway", "operator", "poi", "population", "power", "power_source", "place", "railway", "ref", "religion", "route", "service", "shop", "sport", "surface", "toll", "tourism", "tower:type", "tunnel", "water", "waterway", "wetland", "width", "wood"],
    line: ["access", "addr:housename", "addr:housenumber", "addr:interpolation", "admin_level", "aerialway", "aeroway", "amenity", "area", "barrier", "bicycle", "brand", "bridge", "boundary", "building", "construction", "covered", "culvert", "cutting", "denomination", "disused", "embankment", "foot", "generator:source", "harbour", "highway", "historic", "horse", "intermittent", "junction", "landuse", "layer", "leisure", "lock", "man_made", "military", "motorcar", "name", "natural", "oneway", "operator", "population", "power", "power_source", "place", "railway", "ref", "religion", "route", "service", "shop", "sport", "surface", "toll", "tourism", "tower:type", "tracktype", "tunnel", "water", "waterway", "wetland", "width", "wood"],
    polygon: ["access", "addr:housename", "addr:housenumber", "addr:interpolation", "admin_level", "aerialway", "aeroway", "amenity", "area", "barrier", "bicycle", "brand", "bridge", "boundary", "building", "construction", "covered", "culvert", "cutting", "denomination", "disused", "embankment", "foot", "generator:source", "harbour", "highway", "historic", "horse", "intermittent", "junction", "landuse", "layer", "leisure", "lock", "man_made", "military", "motorcar", "name", "natural", "oneway", "operator", "population", "power", "power_source", "place", "railway", "ref", "religion", "route", "service", "shop", "sport", "surface", "toll", "tourism", "tower:type", "tracktype", "tunnel", "water", "waterway", "wetland", "width", "wood"]
  }
})

tile = Tile.new(*ARGV.map { |a| a.to_i })

puts renderer.render(tile)
