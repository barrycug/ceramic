require "optparse"

module Cover
  
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
            opts.banner = "Usage: render [options] <config> [indices]"
          
            opts.on("-z", "--compress", "Compress output with gzip") do |compress|
              options[:compress] = true
            end
          
            opts.on("-p", "--path PATH", "Output path format string") do |path|
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
        @tileset = eval "Cover::Tileset.build { #{File.read(@config)} }"
      
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
            File.open(get_tile_path(index), "wb+") do |io|
              write_tile_with_index_and_io(index, io)
            end
          else
            write_tile_with_index_and_io(index, STDOUT)
          end
        
        end
      
        def write_tile_with_index_and_io(index, io)
          if @options[:metatiles]
            @tileset.write_metatile(index, io, :compress => @options[:compress], :size => @options[:metatile_size])
          else
            @tileset.write(index, io, :compress => @options[:compress])
          end
        end
    
    end
    
  end
  
end
