require "optparse"

module Ceramic
  
  module Commands
  
    class Server
    
      class << self
      
        def run!
          self.new(*parse_options(ARGV)).run
        end
      
        def parse_options(args)
          options = {
            :Host => "0.0.0.0",
            :Port => 3857
          }
        
          opts = OptionParser.new do |opts|
            opts.banner = "Usage: server <config> [options]"
          
            opts.on("-o", "--host HOST", "listen on HOST (default: 0.0.0.0)") { |host|
              options[:Host] = host
            }

            opts.on("-p", "--port PORT", "use PORT (default: 3857)") { |port|
              options[:Port] = port
            }
            
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
          
          [options, args.shift]
        end
      
      end
    
      def initialize(options, config)
        @options = options
        @config = config
      end
    
      def run
        tileset = Tileset.parse_file(@config)
        
        tileset.setup
      
        begin
          Rack::Server.start(@options.merge(:app => Ceramic::Viewer.new(tileset)))
          
        ensure
          tileset.teardown
        end
      end
    
    end
    
  end
  
end
