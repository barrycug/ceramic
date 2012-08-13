class TargetConfig

  class TargetWriter
  
    def write_feature(row, io)
      io << "{"
      
      io << "\"geometry\":#{row["way"]},"
      io << "\"id\":#{row["osm_id"].to_i},"
      io << "\"type\":\"#{row["osm_type"]}\""
      
      io << "}"
    end
  
  end
  
  def initialize
    
    @target_source = Cover::Source::OSM2PGSQL.new do
      query :point do
        select [:osm_id, [:osm_type, "'point'"]], :zoom => "16-"
      end
      
      query :line, :polygon do
        select [:osm_id, [:osm_type, "case when osm_id < 0 then 'relation' else 'way' end"]], :zoom => "16-"
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
