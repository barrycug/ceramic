require "json"

class BuildingsConfig

  class Writer
  
    def write_feature(row, io)
      io << "{"
      io << "\"geometry\":#{row["way"]},"
      io << "\"id\":#{row["osm_id"].to_i}"
      
      if row.has_key?("height")
        io << ",\"height\":#{row["height"].to_json}"
      end
      
      io << "}"
    end
  
  end
  
  def initialize
    
    @source = Cover::Source::OSM2PGSQL.new(:margin => 0.05) do
      query :polygon, :intersection => false do
        options :zoom => "16-", :conditions => "building IS NOT NULL AND building <> 'no'" do
          select [:osm_id, [:height, "tags -> 'height'"]]
        end
      end
    end
    
    @writer = Writer.new
    
    @maker = Cover::Maker.new(:scale => 1024, :pairs => [[@source, @writer]])
    
  end
  
  def setup
    @connection = PG.connect(dbname: ENV["DBNAME"] || "gis")
    @source.connection = @connection
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    @maker
  end
  
end

Cover.config = BuildingsConfig.new
