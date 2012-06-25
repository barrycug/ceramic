require "rubygems"
require "pg"
require "yaml"
require "#{File.dirname(__FILE__)}/lib/cover"
require "#{File.dirname(__FILE__)}/lib/tile_index"
require "#{File.dirname(__FILE__)}/lib/query_builder"
require "#{File.dirname(__FILE__)}/lib/renderer"
require "#{File.dirname(__FILE__)}/lib/tile_set"
require "#{File.dirname(__FILE__)}/vendor/trollop"

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

config = YAML.load(File.read(options[:config]))
connection = PG.connect(:dbname => options[:database])
cover = Cover.new(config, connection)

if options[:tile]
  
  index = TileIndex.from_str(options[:tile])
  cover.write_output(index, options[:output])
  
elsif options[:tiles]
  
  count = 0
  
  tile_set = TileSet.new(options[:output])
  
  tile_set.create_schema
  tile_set.insert_metadata
  
  File.open(options[:tiles], "r") do |f|
    
    f.each_line do |line|
      
      if line =~ /\d+\/\d+\/\d+/
        
        index = TileIndex.from_str(line)
        data  = cover.render_tile(index)
        
        tile_set.add_tile(index, data)
        
        count += 1
        
        if count % 500 == 0
          puts "#{count} tiles added"
        end
        
      end
      
    end
    
  end
  
  tile_set.finalize
  
  tile_set.close
  
end
