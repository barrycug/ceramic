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
        @format = "js"
      end

      if options[:center] =~ /(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?),(\d+)/
        @lat = $1
        @lon = $2
        @zoom = $3
      end
    
    end
  
    get "/" do
      erb :index
    end
  
    get "/:z/:x/:y" do
      
      hash = get_hash(params[:z], params[:x], params[:y])
      
      if hash != nil
        etag hash
      end
      
      tile = fetch_tile(params[:z], params[:x], params[:y])
      
      if tile
        
        # If the tile is already deflated and the client will accept
        # deflate, pass as-is with content-encoding set.
        
        if @format == "js.deflate"
          encoding = Rack::Utils.select_best_encoding(%w(deflate identity), request.accept_encoding)
          
          if encoding == "deflate"
            headers "Content-Encoding" => "deflate"
          end
        end
        
        content_type :js
        tile
        
      else
        
        404
        
      end
      
    end
    
    get "/:z/:x/:y/inspect" do
      
      @tile = fetch_tile(params[:z], params[:x], params[:y])
      
      if @tile
      
        if @format == "js.deflate"
          @tile = Zlib.inflate(@tile)
        end
      
        erb :inspect
        
      else
        
        404
        
      end
      
    end
  
    protected
  
      # Grab the tile from either the tileset or the renderer
      # and wrap it in a callback.
  
      def fetch_tile(z, x, y)
      
        index = Cover::Index.new(z.to_i, x.to_i, y.to_i)
    
        if @tileset
          
          data = @tileset.select_tile(index)
          
          if data == nil
            nil
          else
            data
          end
          
        else
          
          @maker.render_tile(index)
          
        end
        
      end
      
      def get_hash(z, x, y)
        
        if @tileset
          
          index = Cover::Index.new(z.to_i, x.to_i, y.to_i)
          @tileset.select_hash(index)
          
        else
          
          nil
          
        end
        
      end
  
  end

end
