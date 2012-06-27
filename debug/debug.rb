require "sinatra/base"
require "cover"

module Cover

  class Debug < Sinatra::Base
  
    def initialize(options = {})
    
      super()
      
      if options[:tileset]
  
        database = SQLite3::Database.new(options[:tileset])
        @tileset = Cover::Tileset.new(database)
  
      else
        
        @config_path = options[:config]
        
        config = YAML.load(File.read(@config_path))
        @connection = PG.connect(config["connection"])
        
        reload_maker_config
  
      end
    
      # TODO: determine initial location by asking maker or tileset?
    
      if options[:zoom] =~ /(\d+)/
        @zoom = $1
      else
        @zoom = 13
      end

      if options[:latlon] =~ /(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?)/
        @lat = $1
        @lon = $2
      else
        @lat = 37.478
        @lon = -122.449
      end
    
    end
  
    get "/:z/:x/:y" do
      content_type :js
      reload_maker_config
      fetch_tile_with_callback(params[:z], params[:x], params[:y])
    end
    
    get "/:z/:x/:y/inspect" do
      reload_maker_config
      @tile = fetch_tile(params[:z], params[:x], params[:y])
      erb :inspect
    end
  
    get "/" do
      erb :index
    end
  
    protected
  
      # Grab the tile from either the tileset or the renderer
      # and wrap it in a callback.
  
      def fetch_tile(z, x, y)
      
        index = Cover::Index.new(z.to_i, x.to_i, y.to_i)
    
        data = if @tileset
          @tileset.select_tile(index)
        else
          @maker.render_tile(index)
        end
        
      end
      
      def fetch_tile_with_callback(z, x, y)
        
        data = fetch_tile(z, x, y)
        
        # If we didn't find a tile, return undefined instead.
        
        if data
          "tileData(#{data}, #{z}, #{x}, #{y})"
        else
          "tileData(undefined, #{z}, #{x}, #{y})"
        end
      
      end
      
      def reload_maker_config
        
        time = File.mtime(@config_path)
        
        if time != @last_modified
          
          config = YAML.load(File.read(@config_path))
          
          @maker = Cover::Maker.new(granularity: config["granularity"])

          config["sources"].each do |source|
  
            source = Cover::Sources::PostGIS.new(
              connection: @connection,
              table: source["table"],
              srid: source["srid"],
              geometry_column: source["geometry_column"],
              type: source["type"].to_sym
            )
  
            @maker.sources << source
  
          end
          
          @last_modified = time
        
        end
        
      end
  
  end

end
