require "rubygems"
require "pg"
require "fileutils"
require "#{File.dirname(__FILE__)}/tile"
require "#{File.dirname(__FILE__)}/renderer"
require "#{File.dirname(__FILE__)}/lib/trollop"

options = Trollop::options do
  opt :output, "Output path", :type => :string, :default => "-"
  opt :tile, "Tile index as <z>/<x>/<y>", :type => :string
  opt :tiles, "Path to file containing tile indices, one on each line", :type => :string
  opt :database, "Database name", :type => :string, :default => "gis"
end

if options[:tile] == nil && options[:tiles] == nil
  Trollop::die "must specify either a tile index with --tile or a path to file containing tile indices with --tiles"
end

connection = PG.connect(dbname: options[:database])

renderer = Renderer.new({
  connection: connection,
  granularity: 1000,
  columns: {
    point: ["access", "addr:housename", "addr:housenumber", "addr:interpolation", "admin_level", "aerialway", "aeroway", "amenity", "area", "barrier", "bicycle", "brand", "bridge", "boundary", "building", "capital", "construction", "covered", "culvert", "cutting", "denomination", "disused", "ele", "embankment", "foot", "generator:source", "harbour", "highway", "historic", "horse", "intermittent", "junction", "landuse", "layer", "leisure", "lock", "man_made", "military", "motorcar", "name", "natural", "oneway", "operator", "poi", "population", "power", "power_source", "place", "railway", "ref", "religion", "route", "service", "shop", "sport", "surface", "toll", "tourism", "tower:type", "tunnel", "water", "waterway", "wetland", "width", "wood"],
    line: ["access", "addr:housename", "addr:housenumber", "addr:interpolation", "admin_level", "aerialway", "aeroway", "amenity", "area", "barrier", "bicycle", "brand", "bridge", "boundary", "building", "construction", "covered", "culvert", "cutting", "denomination", "disused", "embankment", "foot", "generator:source", "harbour", "highway", "historic", "horse", "intermittent", "junction", "landuse", "layer", "leisure", "lock", "man_made", "military", "motorcar", "name", "natural", "oneway", "operator", "population", "power", "power_source", "place", "railway", "ref", "religion", "route", "service", "shop", "sport", "surface", "toll", "tourism", "tower:type", "tracktype", "tunnel", "water", "waterway", "wetland", "width", "wood"],
    polygon: ["access", "addr:housename", "addr:housenumber", "addr:interpolation", "admin_level", "aerialway", "aeroway", "amenity", "area", "barrier", "bicycle", "brand", "bridge", "boundary", "building", "construction", "covered", "culvert", "cutting", "denomination", "disused", "embankment", "foot", "generator:source", "harbour", "highway", "historic", "horse", "intermittent", "junction", "landuse", "layer", "leisure", "lock", "man_made", "military", "motorcar", "name", "natural", "oneway", "operator", "population", "power", "power_source", "place", "railway", "ref", "religion", "route", "service", "shop", "sport", "surface", "toll", "tourism", "tower:type", "tracktype", "tunnel", "water", "waterway", "wetland", "width", "wood"]
  }
})

def make_tile(tile, renderer, output_path)
  
  if output_path == "-"
  
    puts renderer.render(tile)
    
  else
    
    formatted = output_path.gsub("%z", tile.z.to_s).gsub("%x", tile.x.to_s).gsub("%y", tile.y.to_s)
    
    FileUtils.mkdir_p(File.dirname(formatted))
    
    File.open(formatted, "w+") do |f|
      f << renderer.render(tile)
    end
    
  end
  
end

if options[:tile]
  
  make_tile(Tile.from_index(options[:tile]), renderer, options[:output])
  
elsif options[:tiles]
  
  File.open(options[:tiles], "r") do |f|
    
    f.each_line do |line|
      make_tile(Tile.from_index(line), renderer, options[:output])
    end
    
  end
  
end

