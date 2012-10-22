require "optparse"
require "fileutils"

module Ceramic
  
  module Commands
  
    class Render
    
      class << self
      
        def run!
          self.new(*parse_options(ARGV)).run
        end
      
        def parse_options(args)
          options = {
            :compress => false,
            :metatiles => false,
            :metatile_size => 8
          }
        
          opts = OptionParser.new do |opts|
            opts.banner = "Usage: render <config> [options] [tile-indices]"
          
            opts.on("-j", "--callback CALLBACK", "JSONP callback function name") do |callback|
              options[:callback] = callback
            end
          
            opts.on("-c", "--compress", "Compress output with gzip") do |compress|
              options[:compress] = true
            end
          
            opts.on("-p", "--path PATH", "Output path format string",
              "  Format specifications:",
              "    %z -- zoom level",
              "    %x -- x coordinate",
              "    %y -- y coordinate",
              "    %h -- path hash (as in mod_tile)") do |path|
              options[:path] = path
            end
          
            opts.on("-m", "--metatiles", "Render metatiles") do |metatiles|
              options[:metatiles] = true
            end
          
            opts.on("-s", "--metatile-size SIZE", Integer, "Metatile size") do |metatile_size|
              options[:metatile_size] = metatile_size
            end
            
            opts.on_tail("-h", "--help", "Show this message") do
              puts opts
              exit
            end
          end
        
          begin
            opts.parse! args
          rescue OptionParser::ParseError => e
            warn e.message
            abort opts.to_s
          end
          
          if args.size < 1
            warn "must specify a config file"
            abort opts.to_s
          end
          
          [options, args.shift, args.size > 0 ? args : nil]
        end
      
      end
    
      def initialize(options, config, indices = nil)
        @options = options
        @config = config
        @indices = indices
      end
    
      def run
        @tileset = Tileset.parse_file(@config)
      
        @tileset.setup
      
        begin
          if @indices
            @indices.each { |index| write_tile_with_input(index) }
          else
            STDIN.each_line { |index| write_tile_with_input(index) }
          end
        ensure
          @tileset.teardown
        end
      end
    
      private
    
        def write_tile_with_input(input)
        
          index = Index.new(input)
        
          if @options[:path]
            tile_path = build_tile_path(index)
            
            FileUtils.mkdir_p(File.dirname(tile_path))
            File.open(tile_path, "wb+") do |io|
              write_tile_with_index_and_io(index, io)
            end
          else
            write_tile_with_index_and_io(index, STDOUT)
          end
        
        end
      
        def write_tile_with_index_and_io(index, io)
          if @options[:metatiles]
            @tileset.write_metatile(index, io, :compress => @options[:compress], :size => @options[:metatile_size], :callback => @options[:callback])
          else
            @tileset.write(index, io, :compress => @options[:compress], :callback => @options[:callback])
          end
        end
        
        def build_tile_path(index)
          path = @options[:path].dup
          
          path.gsub!("%z", index.z.to_s)
          path.gsub!("%x", index.x.to_s)
          path.gsub!("%y", index.y.to_s)
          path.gsub!("%h", hash_path(index.z, index.x, index.y))
          
          path
        end
        
        def hash_path(z, x, y)
          hashes = []
          (0...5).each do |i|
            hashes[i] = ((x & 0x0f) << 4) | (y & 0x0f)
            x >>= 4
            y >>= 4
          end
          "#{z}/%u/%u/%u/%u/%u" % hashes.reverse
        end
    
    end
    
  end
  
end
