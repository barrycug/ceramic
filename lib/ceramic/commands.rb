require "ceramic/commands/render"
require "ceramic/commands/server"
require "ceramic/commands/expand"
require "ceramic/version"

module Ceramic
  
  module Commands
    
    def self.run!

      if ["--version", "-v"].include?(ARGV.first)
        puts "Ceramic #{Ceramic::VERSION}"
        exit(0)
      end

      commands = {
        "expand" => Ceramic::Commands::Expand,
        "render" => Ceramic::Commands::Render,
        "server" => Ceramic::Commands::Server
      }

      command = commands.detect do |name, klass|
        ARGV.first == name
      end

      if command.nil?
        puts "Usage: ceramic [-v|--version] <command> [args]"
        puts
        puts "Commands:"
        puts "   render   Render GeoJSON tiles to disk"
        puts "   server   Start a web server which renders tiles on demand"
        puts "   expand   Expand tile indices and bounding boxes"
      else
        command[1].run!
      end
      
    end
    
  end
  
end
