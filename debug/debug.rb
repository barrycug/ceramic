require "sinatra/base"
require "cover"
require "zlib"

module Cover

  class Debug < Sinatra::Base
  
    def initialize(options = {})
    
      super()
      
      if options[:tileset]
        @tileset = options[:tileset]
        @format = @tileset.get_metadata["format"]
      else
        @maker = options[:maker]
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
      fetch_tile_with_callback(params[:z], params[:x], params[:y])
    end
    
    get "/:z/:x/:y/inspect" do
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
    
        if @tileset
          
          data = @tileset.select_tile(index)
          
          # Uncompress data if necessary.
          # TODO: content negotiation
          
          if data != nil && @format == "js.gz"
            Zlib.inflate(data)
          else
            data
          end
          
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
  
  end

end
