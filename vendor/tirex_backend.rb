require "syslog"
require "socket"
require "fileutils"
require "timeout"
require "tempfile"

class TirexBackend
  
  # As defined by Tirex::MAX_PACKET_SIZE
  MAX_PACKET_SIZE = 512
  
  MetatileInfo = Struct.new(:map, :x, :y, :z)
  
  def self.run(handler)
    backend = self.new(handler)
    backend.run
  end
  
  def initialize(handler)
    
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
    
    # Read map configs
    
    @map_configs = {}
    
    if @config.has_key?("map_configs")
      @config["map_configs"].split(/\s+/).each do |path|
        config = read_map_config(path)
        @map_configs[config["name"]] = config
      end
    end
    
    # Setup handler
    
    @handler = handler
    @handler.setup(@map_configs, @config["debug"] != nil) if @handler.respond_to?(:setup)
    
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
      
      log_debug("Sending alive message to backend manager")
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
    
    log_debug("Asking handler to do teardown...")
    @handler.teardown if @handler.respond_to?(:teardown)
    
    @parent.close
    
  end
  
  private
  
    def log_debug(message)
      if @config["debug"] != nil
        Syslog.debug(message)
      end
    end
  
    def process_message(message)
      request = deserialize_message(message)
      log_debug("Processing request: #{request.inspect}")
      
      response = process_request(request)
      log_debug("Returning response: #{response.inspect}")
      
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
      
      unless @map_configs.has_key?(request["map"])
        raise ArgumentError, "Render request for unknown map: #{request["map"]}"
      end
      
      map_config = @map_configs[request["map"]]
      metatile_info = MetatileInfo.new(request["map"], request["x"].to_i, request["y"].to_i, request["z"].to_i)
      metatile_path = map_config["tiledir"] + "/" + xyz_to_path(metatile_info.x, metatile_info.y, metatile_info.z) + ".meta"
      
      # Open a temporary file to write the metatile. When done, copy the temporary
      # file to its final path.
      
      tempfile = Tempfile.new("metatile-#{request["map"]}")
      
      begin
        
        start = Time.now
        
        @handler.write(metatile_info, tempfile)
        
        elapsed = Time.now - start
        
        FileUtils.mkdir_p(File.dirname(metatile_path))
        FileUtils.cp(tempfile.path, metatile_path)
        FileUtils.chmod(0644, metatile_path)
        
      ensure
        
        tempfile.close
        tempfile.unlink
        
      end
      
      log_debug("Metatile written to: #{metatile_path}")
      
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
