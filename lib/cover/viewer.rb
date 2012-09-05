require "sinatra/base"
require "cover"
require "zlib"
require "stringio"
require "json"

module Cover

  class Viewer < Sinatra::Base
    
    set :root, File.dirname(__FILE__) + "/../viewer/"
  
    def initialize(options = {})
    
      super()
      
      @maker = options[:maker]

      if options[:center] =~ /(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?),(\d+)/
        @center = [$1, $2, $3]
      end
    
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
        tile_index = Cover::TileIndex.new(params[:z].to_i, params[:x].to_i, params[:y].to_i)
        
        io = StringIO.new("")
        @maker.write_tile(tile_index, io)
        io.string
      end
  
  end

end
