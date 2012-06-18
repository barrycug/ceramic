require "rubygems"
require "pg"
require "fileutils"
require "yaml"
require "#{File.dirname(__FILE__)}/lib/tile"
require "#{File.dirname(__FILE__)}/lib/maker"
require "#{File.dirname(__FILE__)}/vendor/trollop"

def make_tile(tile, maker, output_path)
  
  if output_path == "-"
    puts maker.render(tile)
  else
    formatted = output_path.gsub("%z", tile.z.to_s).gsub("%x", tile.x.to_s).gsub("%y", tile.y.to_s)
    
    puts "writing output to #{formatted}"
    FileUtils.mkdir_p(File.dirname(formatted))
    File.open(formatted, "w+") do |f|
      f << renderer.render(tile)
    end
  end
  
end


options = Trollop::options do
  opt :output, "Output path", :type => :string, :default => "-"
  opt :tile, "Tile index as <z>/<x>/<y>", :type => :string
  opt :tiles, "Path to file containing tile indices, one on each line", :type => :string
  opt :database, "Database name", :type => :string, :default => "gis"
  opt :config, "Configuration file", :type => :string, :default => "config.yml"
end

if options[:tile] == nil && options[:tiles] == nil
  Trollop::die "must specify either a tile index with --tile or a path to file containing tile indices with --tiles"
end

connection = PG.connect(dbname: options[:database])
config = YAML.load(File.read(options[:config]))
maker = Maker.new(connection, config)

if options[:tile]
  
  maker.write_tile(Tile.from_index(options[:tile]), options[:output])
  
elsif options[:tiles]
  
  File.open(options[:tiles], "r") do |f|
    f.each_line do |line|
      if line =~ /\d+\/\d+\/\d+/
        puts "writing tile #{line}"
        maker.write_tile(Tile.from_index(line), options[:output])
      end
    end
  end
  
end
