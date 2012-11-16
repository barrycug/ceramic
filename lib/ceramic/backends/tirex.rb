require "syslog"
require "socket"
require "fileutils"
require "timeout"
require "tempfile"

module Ceramic
  
  module Backends

    class Tirex
  
      # As defined by Tirex::MAX_PACKET_SIZE
      MAX_PACKET_SIZE = 512
  
      MetatileInfo = Struct.new(:map, :x, :y, :z)
  
      def self.run!(options = {})
        self.new(options).run
      end
  
      def initialize(options = {})
        
        # No configuration?
        
        unless ENV.has_key?("TIREX_BACKEND_NAME")
          puts "No configuration environment variables found. Note that the Tirex backend is meant to be invoked via Tirex, not directly."
          exit!
        end
    
        # Read config from environment variables
    
        @config = {}
        @config["name"] = ENV["TIREX_BACKEND_NAME"]
        @config["port"] = ENV["TIREX_BACKEND_PORT"]
        @config["syslog_facility"] = ENV["TIREX_BACKEND_SYSLOG_FACILITY"]
        @config["map_configs"] = ENV["TIREX_BACKEND_MAP_CONFIGS"]
        @config["alive_timeout"] = ENV["TIREX_BACKEND_ALIVE_TIMEOUT"]
        @config["pipe_fileno"] = ENV["TIREX_BACKEND_PIPE_FILENO"]
        @config["socket_fileno"] = ENV["TIREX_BACKEND_SOCKET_FILENO"]
        @config["debug"] = ENV["TIREX_BACKEND_DEBUG"]
    
        # Set up logging
    
        syslog_facility = case @config["syslog_facility"]
        when "local0"
          Syslog::LOG_LOCAL0
        when "local1"
          Syslog::LOG_LOCAL1
        when "local2"
          Syslog::LOG_LOCAL2
        when "local3"
          Syslog::LOG_LOCAL3
        when "local4"
          Syslog::LOG_LOCAL4
        when "local5"
          Syslog::LOG_LOCAL5
        when "local6"
          Syslog::LOG_LOCAL6
        when "local7"
          Syslog::LOG_LOCAL7
        when "user"
          Syslog::LOG_USER
        when "daemon"
          Syslog::LOG_DAEMON
        end
    
        Syslog.open(@config["name"], Syslog::LOG_PID, syslog_facility)
    
        if @config["debug"]
          Syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_DEBUG)
        else
          Syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_ERR)
        end
    
        # Read map configs
    
        @map_configs = {}
    
        if @config.has_key?("map_configs")
          @config["map_configs"].split(/\s+/).each do |path|
            config = read_map_config(path)
            @map_configs[config["name"]] = config
          end
        end
    
        Syslog.debug("map_configs=#{map_configs.inspect}")
    
        # Setup map configs (first get tilesets and options, then send #setup to tilesets)
    
        @map_configs.each do |name, map_config|
      
          if map_config.has_key?("ceramic_config_path")
            map_config[:tileset] = Tileset.parse_file(map_config["ceramic_config_path"])
          else
            raise ArgumentError, "ceramic_config_path is not set in Tirex config #{name}"
          end
      
          if map_config.has_key?("ceramic_metatile_size")
            map_config[:metatile_size] = map_config["ceramic_metatile_size"].to_i
          else
            map_config[:metatile_size] = 8
          end
      
          if map_config.has_key?("ceramic_compress") && map_config["ceramic_metatile_size"].to_i == 1
            map_config[:compress] = true
          end
      
          Syslog.debug("Set up configuration for map=#{name}: #{map_config[name].inspect}")
      
        end
    
        @map_configs.each do |name, map_config|
          if map_config[:tileset].respond_to?(:setup)
            Syslog.debug("Sending setup to tileset for map=#{name}")
            map_config[:tileset].setup
          end
        end
    
        # Open keepalive pipe
    
        @parent = IO.new(@config["pipe_fileno"].to_i, "w")
    
      end
  
      def run
    
        # Open sockets and pipes
    
        if @config["socket_fileno"]
          @socket = Socket::for_fd(@config["socket_fileno"].to_i)
        else
          @socket = UDPSocket.new
          @socket.bind("localhost", @config["port"].to_i)
        end
    
        # Trap signal
    
        Signal.trap("HUP") do
          @keep_running = false
        end
    
        # Socket loop
    
        @keep_running = true
    
        while @keep_running do
      
          Syslog.debug("Sending alive message to backend manager")
          @parent.write_nonblock("alive")
      
          begin
            message = nil
            addr = nil
        
            Timeout.timeout(@config["alive_timeout"].to_i || 5) do
              message, addr = *@socket.recvfrom(MAX_PACKET_SIZE)
            end
        
            @socket.send(process_message(message), 0, addr)
          rescue Timeout::Error
          end
      
        end
    
        # Teardown
    
        Syslog.debug("Teardown")
    
        @map_configs.each do |name, map_config|
          if map_config[:tileset].respond_to?(:teardown)
            Syslog.debug("Sending teardown to tileset for map=#{name}")
            map_config[:tileset].teardown
          end
        end
    
        @parent.close
    
      end
  
      private
  
        def process_message(message)
          request = deserialize_message(message)
          Syslog.debug("Processing request: #{request.inspect}")
      
          response = process_request(request)
          Syslog.debug("Returning response: #{response.inspect}")
      
          serialize_message(response)
        end
    
        def deserialize_message(string)
          message = {}
          string.split("\n").each do |line|
            key, value = line.split("=", 2)
            message[key] = value
          end
          message
        end
    
        def serialize_message(message)
          message.map { |k,v| "#{k}=#{v}" }.join("\n")
        end
    
        def process_request(request)
          begin
            if request["type"] == "metatile_render_request"
              process_render_request(request)
            else
              raise ArgumentError, "Unknown request type: #{request["type"]}"
            end
          rescue => e
            { "id" => request["id"], "result" => "fail", "errmsg" => e.to_s }
          end
        end
    
        def process_render_request(request)
      
          Syslog.debug("Request to write metatile: map=#{request["map"]} x=#{request["x"]} y=#{request["y"]} z=#{request["z"]}")
      
          unless @map_configs.has_key?(request["map"])
            raise ArgumentError, "Render request for unknown map: #{request["map"]}"
          end
      
          map_config = @map_configs[request["map"]]
      
          metatile_info = MetatileInfo.new(request["map"], request["x"].to_i, request["y"].to_i, request["z"].to_i)
          metatile_path = map_config["tiledir"] + "/" + xyz_to_path(metatile_info.x, metatile_info.y, metatile_info.z) + ".meta"
          metatile_index = Index.new(metatile_info.z, metatile_info.x, metatile_info.y)
      
          # Open a temporary file to write the metatile. When done, move the temporary
          # file to its final path.
      
          tempfile = Tempfile.new("metatile-#{request["map"]}")
      
          begin
        
            start = Time.now
        
            map_config[:tileset].write_metatile(metatile_index, tempfile, :size => map_config[:metatile_size], :compress => map_config[:compress])
        
            elapsed = Time.now - start
        
            FileUtils.mkdir_p(File.dirname(metatile_path))
            FileUtils.mv(tempfile.path, metatile_path)
            FileUtils.chmod(0644, metatile_path)
        
          ensure
        
            tempfile.close
            tempfile.unlink
        
          end
      
          Syslog.debug("Metatile written to: #{metatile_path}")
      
          {
            "type" => "metatile_render_request",
            "result" => "ok",
            "id" => request["id"],
            "render_time" => (elapsed * 1000).to_i.to_s
          }
      
        end
    
        def xyz_to_path(x, y, z)
          hashes = []
          (0...5).each do |i|
            hashes[i] = ((x & 0x0f) << 4) | (y & 0x0f)
            x >>= 4
            y >>= 4
          end
          "#{z}/%u/%u/%u/%u/%u" % hashes.reverse
        end
  
        def read_map_config(path)
          config = {}
          File.open(path, "r") do |f|
            f.lines do |line|
              line = line.sub(/#.*$/, "")
              next if line =~ /^\s*$/
              if line =~ /^([a-z0-9_]+)\s*=\s*(\S*)\s*$/
                config[$1] = $2
              end
            end
          end
          config
        end
  
    end

  end
  
end
