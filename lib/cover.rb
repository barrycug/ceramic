require "fileutils"

class Cover
  
  def initialize(query_builder, connection, renderer)
    @query_builder = query_builder
    @connection = connection
    @renderer = renderer
  end
  
  # Render a single tile specified by the index

  def render_tile(index)
  
    @renderer.output(index) do |r|
      @query_builder.queries(index).each do |q|
        @connection.exec(*q) do |result|
          result.each do |row|
            r << row
          end
        end
      end
    end
  
  end
  
  # Call render_tile and use the result to write to a path given
  # by the path specification and the index. The path specification
  # may have %z, %x, and %y placeholders. Directories will be created
  # by FileUtils.mkdir_p.

  def write_output(index, path)
    
    output = render_tile(index)
  
    if path == "-"
      puts output
    else
      formatted = path.gsub("%z", index.z.to_s).gsub("%x", index.x.to_s).gsub("%y", index.y.to_s)
    
      FileUtils.mkdir_p(File.dirname(formatted))
      File.open(formatted, "w+") do |f|
        f << output
      end
    end
  
  end
  
end
