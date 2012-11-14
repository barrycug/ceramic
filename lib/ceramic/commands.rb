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
        "server" => Ceramic::Commands::Server,
        "tirex"  => Ceramic::Commands::Tirex
      }
      
      command_argument = ARGV.shift

      selected_command = commands.detect do |name, klass|
        command_argument == name
      end

      if selected_command.nil?
        puts "Usage: ceramic [-v|--version] <command> [args]"
        puts
        puts "Commands:"
        puts "   render   Render GeoJSON tiles to disk"
        puts "   server   Start a web server which renders tiles on demand"
        puts "   expand   Expand tile indices and bounding boxes"
        puts "   tirex    Start a Tirex backend (to be invoked by Tirex)"
      else
        selected_command[1].run!
      end
      
    end
    
  end
  
end
