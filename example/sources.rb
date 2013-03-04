class CustomSource
  
  def initialize(options = {})
    @message = options[:message]
  end
  
  def setup
    $stderr.puts "CustomSource is setting up!"
  end
  
  def teardown
    $stderr.puts "CustomSource is all done..."
  end
  
  def query(index, options = {}, &block)
    yield({ "message" => @message })
  end
  
end

source CustomSource, :message => "Here's a custom source"
