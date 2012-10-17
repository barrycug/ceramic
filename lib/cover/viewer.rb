require "sinatra/base"
require "cover"
require "zlib"
require "stringio"
require "json"

module Cover

  class Viewer < Sinatra::Base
    
    set :root, File.dirname(__FILE__) + "/../viewer/"
  
    def initialize(tileset)
      
      super()
      
      @tileset = tileset
      
    end
  
    get "/" do
      erb :index
    end
  
    get "/:z/:x/:y" do
      
      content_type :js
      headers "Access-Control-Allow-Origin" => "*"
      
      fetch_tile(params)
      
    end
    
    get "/:z/:x/:y/inspect" do
      
      start = Time.now
      
      @tile = fetch_tile(params)
      
      @fetch_time = Time.now - start
      @file_size = @tile.bytesize
      @compressed_file_size = Zlib.deflate(@tile).bytesize
    
      erb :inspect
      
    end
  
    protected
    
      def fetch_tile(params)
        tile_index = Cover::Index.new(params[:z].to_i, params[:x].to_i, params[:y].to_i)
        
        io = StringIO.new("")
        @tileset.write(tile_index, io)
        io.string
      end
  
  end

end
