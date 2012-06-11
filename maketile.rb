require "rubygems"
require "pg"
require "#{File.dirname(__FILE__)}/tile"
require "#{File.dirname(__FILE__)}/renderer"

connection = PG.connect(dbname: "gis")

renderer = Renderer.new({
  connection: connection,
  granularity: 1000
})

tile = Tile.new(*ARGV.map { |a| a.to_i })

puts renderer.render(tile)
