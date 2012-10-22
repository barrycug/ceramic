require "optparse"

module Ceramic
  
  module Commands
  
    class Expand
    
      class << self
      
        def run!
          self.new(*parse_options(ARGV)).run
        end
      
        def parse_options(args)
          options = {
            :zoom => []
          }
        
          opts = OptionParser.new do |opts|
            opts.banner = "Usage: expand [options] [indices-or-bboxes]"
          
            opts.on("-z", "--zoom ZOOM_LEVELS",
              "Comma-separated zoom levels or ranges",
              "  (For example: 2,4,6-8)") do |zoom|
              options[:zoom] = parse_zoom_levels(zoom)
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
          
          if options[:zoom].size < 1
            warn "must specify one or more zoom levels"
            abort opts.to_s
          end
          
          [options, args.size > 0 ? args : nil]
        end
        
        private
        
          def parse_zoom_levels(zoom)
            zoom.split(",").inject([]) do |levels, level|
              if level =~ /^(\d+)\-(\d+)$/
                levels += Range.new($1.to_i, $2.to_i).to_a
              elsif level =~ /^(\d+)$/
                levels << $1.to_i
              else
                raise OptionParser::InvalidArgument, zoom
              end
              levels
            end
          end
      
      end
    
      def initialize(options, inputs = nil)
        @options = options
        @inputs = inputs
      end
    
      def run
        if @inputs
          @inputs.each { |input| write_expanded_input(input) }
        else
          STDIN.each_line { |input| write_expanded_input(input) }
        end
      end
      
      private
      
        def write_expanded_input(input)
          
          if input =~ /^(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?),(\-?\d+(?:\.\d+)?)$/
            @options[:zoom].each { |level| expand_bbox([$1.to_f, $2.to_f, $3.to_f, $4.to_f], level) }
          elsif input =~ /^(\d+)\/(\d+)\/(\d+)$/
            @options[:zoom].each { |level| expand_index([$1.to_i, $2.to_i, $3.to_i], level) }
          else
            raise ArgumentError, "invalid input: #{input}"
          end
          
        end
        
        def expand_index(index, zoom)
          
          if zoom < index[0]
            return
          end
    
          difference = zoom - index[0]
    
          z_range = 2 ** difference
          x_base = index[1] << difference
          y_base = index[2] << difference
    
          (0...z_range).each do |x_index|
            (0...z_range).each do |y_index|
              STDOUT << [zoom, x_base + x_index, y_base + y_index].join("/") + "\n"
            end
          end
          
        end
        
        def expand_bbox(bbox, zoom)
          
          left, top = *latlon_to_tile(bbox[2], bbox[1], zoom).map { |c| c.floor.to_i }
          right, bottom = *latlon_to_tile(bbox[0], bbox[3], zoom).map { |c| c.ceil.to_i }
          
          (left...right).each do |x|
            (top...bottom).each do |y|
              STDOUT << [zoom, x, y].join("/") + "\n"
            end
          end
          
        end
        
        # Note: returns fractional tile numbers
        
        def latlon_to_tile(lat_deg, lon_deg, zoom)
          lat_rad = (lat_deg / 360.0) * Math::PI * 2.0
          n = 2.0 ** zoom
          x = (lon_deg + 180.0) / 360.0 * n
          y = (1.0 - Math.log(Math.tan(lat_rad) + (1 / Math.cos(lat_rad))) / Math::PI) / 2.0 * n
          [x, y]
        end
    
    end
    
  end
  
end
