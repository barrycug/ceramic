require "sinatra/base"
require "cover"
require "zlib"

module Cover

  class Viewer < Sinatra::Base
  
    def initialize(options = {})
    
      super()
      
      if options[:tileset]
        @tileset = options[:tileset]
        @format = @tileset.get_metadata["format"]
      else
        @maker = options[:maker]
      end

      if options[:center] =~ /(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?),(\d+)/
        @lat = $1
        @lon = $2
        @zoom = $3
      end
    
    end
  
    get "/:z/:x/:y" do
      
      tile = fetch_tile(params[:z], params[:x], params[:y])
      
      if tile
        content_type :js
        tile
      else
        404
      end
      
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
          
          if data != nil && @format == "js.deflate"
            Zlib.inflate(data)
          else
            data
          end
          
        else
          
          @maker.render_tile(index)
          
        end
        
      end
  
  end

end