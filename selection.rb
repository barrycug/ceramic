require "json"

class SelectionConfig

  class Writer
  
    def write_feature(row, io)
      io << "{"
      io << "\"type\":\"osm\","
      io << "\"id\":#{row["osm_id"]},"
      io << "\"geometry\":#{row["way"]},"
      
      if row.has_key?("point") && row["point"] =~ /(\[-?\d+,-?\d+\])/
        io << "\"point\":#{$1},"
      end
    
      tag_members = row.inject([]) do |members, (name, value)|
        members << "\"#{name}\":#{value.to_json}" unless %w(way point osm_id).include?(name) || value.nil?
        members
      end
    
      io << "\"tags\":{"
      io << tag_members.join(",")
      io << "}"
    
      io << "}"
    end
  
  end
  
  def initialize
    
    @osm_source = Cover::Source::OSM2PGSQL.new do
      
      # roads (based on High Road)

      conditions :table => :line do
        select %w(ref), :zoom => "8-", :sql => "highway IN ('motorway', 'trunk')"
        select %w(name ref), :zoom => "10-", :sql => "highway IN ('motorway', 'trunk')"
        select %w(name ref), :zoom => "12-", :sql => "highway IN ('primary', 'secondary')"
        select %w(name), :zoom => "14-", :sql => "highway IN ('tertiary', 'residential', 'unclassified', 'road')"
        select %w(name), :zoom => "15-", :sql => "highway IN ('service', 'minor', 'footpath', 'track', 'footway', 'steps', 'pedestrian', 'path', 'cycleway', 'motorway_link', 'trunk_link', 'primary_link', 'secondary_link', 'tertiary_link')"
    
        select %w(highway), :zoom => "8-", :sql => "highway IN ('motorway', 'trunk')"
        select %w(highway tunnel bridge), :zoom => "10-", :sql => "highway IN ('motorway', 'trunk', 'primary', 'secondary')"
        select %w(highway tunnel bridge), :zoom => "11-", :sql => "highway IN ('tertiary')"
        select %w(highway tunnel bridge), :zoom => "12-", :sql => "highway IN ('trunk_link', 'residential', 'unclassified', 'road')"
        select %w(highway tunnel bridge), :zoom => "13-", :sql => "highway IN ('motorway_link', 'trunk_link', 'primary_link', 'secondary_link')"
        select %w(highway tunnel bridge), :zoom => "14-", :sql => "highway IN ('minor') OR railway IN ('rail')"
        select %w(highway tunnel bridge), :zoom => "15-", :sql => "highway IN ('footpath', 'track', 'footway', 'steps', 'pedestrian', 'path', 'cycleway') OR railway IN ('rail', 'tram', 'light_rail', 'narrow_gauge', 'monorail')"
      end

      # addressing (this and below based on OSM's Mapnik stylesheets)
  
      conditions :table => :point do
        select %w(addr:housenumber), :zoom => "17-", :sql => "\"addr:housenumber\" is not null"
        select %w(addr:housename), :zoom => "17-", :sql => "\"addr:housename\" is not null"
      end
  
      conditions :table => :polygon do
        select %w(addr:housenumber), :zoom => "17-", :sql => "\"addr:housenumber\" is not null and building is not null"
        select %w(addr:housename), :zoom => "17-", :sql => "\"addr:housename\" is not null and building is not null"
      end
  
      # placenames
  
      conditions :table => :point do
        select %w(place name), :zoom => "2-6", :sql => "place = 'country'"
        select %w(place ref), :zoom => "4", :sql => "place = 'state'"
        select %w(place name), :zoom => "5-8", :sql => "place = 'state'"
        select %w(place capital name), :zoom => "5-14", :sql => "place in ('city', 'metropolis', 'town') and capital = 'yes'"
        select %w(place name), :zoom => "6-", :sql => "place in ('city', 'metropolis', 'town', 'large_town', 'small_town')"
        select %w(place name), :zoom => "12-", :sql => "place in ('suburb', 'village', 'large_village', 'hamlet', 'locality', 'isolated_dwelling', 'farm')"
      end
  
      # buildings
  
      conditions :table => :polygon do
        select %w(railway building amenity), :zoom => "10-11", :sql => "railway = 'station' or building in ('station', 'supermarket') or amenity = 'place_of_worship'"
        select %w(building aeroway), :zoom => "12-", :sql => "(building is not null and building not in ('no', 'planned')) or aeroway = 'terminal'"
      end
      
    end
    
    @writer = Writer.new
    
    @maker = Cover::Maker.new(:scale => 8192, :pairs => [[@osm_source, @writer]])
    
  end
  
  def setup
    @connection = PG.connect(dbname: "gis")
    @osm_source.connection = @connection
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    @maker
  end
  
end

Cover.config = SelectionConfig.new
