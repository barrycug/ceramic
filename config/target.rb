class TargetConfig

  class TargetWriter
  
    def write_feature(row, io)
      io << "{"
      io << "\"geometry\":#{row["way"]},"
      io << "\"id\":#{row["osm_id"].to_i}"
      io << "}"
    end
  
  end
  
  def initialize
    
    @target_source = Cover::Source::OSM2PGSQL.new do
      query :point, :simplify => false do
        select [:osm_id], :zoom => "16-"
      end
      
      query :line, :polygon, :simplify => false, :point => false do
        select [:osm_id], :zoom => "16-"
      end
    end
    
    @target_writer = TargetWriter.new
    
    @maker = Cover::Maker.new(:scale => 1024, :pairs => [[@target_source, @target_writer]])
    
  end
  
  def setup
    @connection = PG.connect(dbname: ENV["DBNAME"] || "gis")
    @target_source.connection = @connection
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    @maker
  end
  
end

Cover.config = TargetConfig.new