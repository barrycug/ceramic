require "sinatra/base"
require "cover"
require "zlib"
require "stringio"
require "json"

module Cover

  class Viewer < Sinatra::Base
  
    def initialize(options = {})
    
      super()
      
      if options[:zoom]
        @zoom = options[:zoom]
      end
      
      if options[:tileset]
        @tileset = options[:tileset]
        @format = @tileset.select_metadata["format"]
      else
        @maker = options[:maker]
        @format = "js"
      end

      if options[:center] =~ /(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?),(\d+)/
        @center = [$1,$2,$3]
      end
    
    end
  
    get "/" do
      erb :index
    end
  
    get "/:z/:x/:y" do
      
      if @zoom && !@zoom.include?(params[:z].to_i)
        halt 404
      end
      
      hash = get_hash(params[:z], params[:x], params[:y])
      
      if hash != nil
        etag hash
      end
      
      tile = fetch_tile(params[:z], params[:x], params[:y])
      
      if tile == nil
        halt 404
      end
        
      # If the tile is already deflated and the client will accept
      # deflate, pass as-is with content-encoding set. Otherwise,
      # inflate the tile.
      
      if @format == "js.deflate"
        encoding = Rack::Utils.select_best_encoding(%w(deflate identity), request.accept_encoding)
        
        if encoding == "deflate"
          headers "Content-Encoding" => "deflate"
        else
          tile = Zlib.inflate(tile)
        end
      end
      
      content_type :js
      
      tile
      
    end
    
    get "/:z/:x/:y/inspect" do
      
      if @zoom && !@zoom.include?(params[:z].to_i)
        halt 404
      end
      
      start = Time.now
      @tile = fetch_tile(params[:z], params[:x], params[:y])
      @fetch_time = Time.now - start
      
      if @tile == nil
        halt 404
      end
      
      if @format == "js.deflate"
        @tile = Zlib.inflate(@tile)
      end
      
      parsed = JSON.parse(@tile.force_encoding("UTF-8"))
      
      @feature_count = parsed["features"].size
      
      @combined_keys = %w(name ref ele layer operator)
      
      @distribution = parsed["features"].inject({}) do |dist, feature|
        if Enumerable === feature["tags"]
          tags = feature["tags"].inject({}) do |t, (key, value)|
            if @combined_keys.include?(key)
              t[key] = true
            else
              t[key] = value
            end
            t
          end
          dist[tags] = (dist[tags] || 0) + 1
        end
        dist
      end.to_a.sort_by do |p|
        p[1]
      end.reverse.map do |p|
        [JSON.dump(p[0]), p[1]]
      end
    
      erb :inspect
      
    end
    
    # get "/:z/:x/:y/metatile" do
    #   
    #   if @zoom && !@zoom.include?(params[:z].to_i)
    #     halt 404
    #   end
    #   
    #   if @tileset
    #     halt 404
    #   end
    #   
    #   params[:size] ||= "4"
    #   
    #   index = Cover::Index.new(params[:z].to_i, params[:x].to_i, params[:y].to_i)
    #   @tiles = @maker.render_metatile(index, params[:size].to_i)
    # 
    #   erb :metatile
    #   
    # end
  
    protected
  
      # Grab the tile from either the tileset or the renderer
      # and wrap it in a callback.
  
      def fetch_tile(z, x, y)
      
        index = Cover::TileIndex::Slippy.new(z.to_i, x.to_i, y.to_i)
    
        if @tileset
          
          data = @tileset.select_tile(index)
          
          if data == nil
            nil
          else
            data
          end
          
        else
          
          io = StringIO.new("")
          @maker.write_tile(index, io)
          io.string
          
        end
        
      end
      
      def get_hash(z, x, y)
        
        if @tileset
          
          index = Cover::TileIndex::Slippy.new(z.to_i, x.to_i, y.to_i)
          @tileset.select_hash(index)
          
        else
          
          nil
          
        end
        
      end
  
  end

end
