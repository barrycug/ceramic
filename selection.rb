class SelectionConfig
  
  def initialize
    
    @lines_source = Cover::Source.new(
      :table => "planet_osm_line",
      :geometry => "way",
      :srid => 900913,
      :columns => ["osm_id", "way"],
      :selections => [
        Cover::Selection.new(:columns => %w(ref), :zoom => "8-", :sql => "highway IN ('motorway', 'trunk')"),
        Cover::Selection.new(:columns => %w(name ref), :zoom => "10-", :sql => "highway IN ('motorway', 'trunk')"),
        Cover::Selection.new(:columns => %w(name ref), :zoom => "12-", :sql => "highway IN ('primary', 'secondary')"),
        Cover::Selection.new(:columns => %w(name), :zoom => "14-", :sql => "highway IN ('tertiary', 'residential', 'unclassified', 'road')"),
        Cover::Selection.new(:columns => %w(name), :zoom => "15-", :sql => "highway IN ('service', 'minor', 'footpath', 'track', 'footway', 'steps', 'pedestrian', 'path', 'cycleway', 'motorway_link', 'trunk_link', 'primary_link', 'secondary_link', 'tertiary_link')"),
        Cover::Selection.new(:columns => %w(highway), :zoom => "8-", :sql => "highway IN ('motorway', 'trunk')"),
        Cover::Selection.new(:columns => %w(highway tunnel bridge), :zoom => "10-", :sql => "highway IN ('motorway', 'trunk', 'primary', 'secondary')"),
        Cover::Selection.new(:columns => %w(highway tunnel bridge), :zoom => "11-", :sql => "highway IN ('tertiary')"),
        Cover::Selection.new(:columns => %w(highway tunnel bridge), :zoom => "12-", :sql => "highway IN ('trunk_link', 'residential', 'unclassified', 'road')"),
        Cover::Selection.new(:columns => %w(highway tunnel bridge), :zoom => "13-", :sql => "highway IN ('motorway_link', 'trunk_link', 'primary_link', 'secondary_link')"),
        Cover::Selection.new(:columns => %w(highway tunnel bridge), :zoom => "14-", :sql => "highway IN ('minor') OR railway IN ('rail')"),
        Cover::Selection.new(:columns => %w(highway tunnel bridge), :zoom => "15-", :sql => "highway IN ('footpath', 'track', 'footway', 'steps', 'pedestrian', 'path', 'cycleway') OR railway IN ('rail', 'tram', 'light_rail', 'narrow_gauge', 'monorail')")
      ]
    )
    
    @writer = Cover::Writer.new
    
    @maker = Cover::Maker.new(:scale => 1024, :pairs => [[@lines_source, @writer]])
    
  end
  
  def setup
    @connection = PG.connect(dbname: "gis")
    @lines_source.connection = @connection
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    @maker
  end
  
end

Cover.config = SelectionConfig.new
