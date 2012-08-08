require "json"

class SelectionConfig

  class OSMWriter
  
    def write_feature(row, io)
      io << "{"
      io << "\"type\":\"osm\","
      io << "\"id\":#{row["osm_id"]}," if row.has_key?("osm_id")
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

  class CoastlineWriter
    
    def initialize(options = {})
      @geometry = options[:geometry] || "the_geom"
    end
  
    def write_feature(row, io)
      io << "{"
      io << "\"type\":\"coastline\","
      io << "\"geometry\":#{row[@geometry]}"
      io << "}"
    end
  
  end
  
  def initialize
    
    @coastline_source = Cover::Source::Coastline.new("coastlines", :geometry => "geom", :zoom => "9-")
    
    @osm_source = Cover::Source::OSM2PGSQL.new do
      
      select %w(osm_id aeroway name), :table => :point, :zoom => "10-", :sql => "aeroway = 'aerodrome'"
      select %w(osm_id aeroway), :table => :polygon, :zoom => "13-", :sql => "aeroway = 'aerodrome'"

      select %w(osm_id amenity), :table => :point, :zoom => "15-", :sql => "amenity = 'bus_station'"
      select %w(osm_id amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'cinema'"
      select %w(osm_id amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'courthouse'"
      select %w(osm_id amenity), :table => :point, :zoom => "15-", :sql => "amenity = 'fuel'"
      select %w(osm_id amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'kindergarten'"
      select %w(osm_id amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'library'"
      select %w(osm_id amenity), :table => :point, :zoom => "15-", :sql => "amenity = 'museum'"
      select %w(osm_id amenity), :table => [:point, :polygon], :zoom => "15-", :sql => "amenity = 'parking'"
      select %w(osm_id amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'pharmacy'"
      select %w(osm_id amenity name religion), :table => [:point, :polygon], :zoom => "14-", :sql => "amenity = 'place_of_worship'"
      select %w(osm_id amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'post_office'"
      select %w(osm_id amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'restaurant'"
      select %w(osm_id amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'school'"
      select %w(osm_id amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'theatre'"
      select %w(osm_id amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'toilets'"
      select %w(osm_id amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'university'"
      
      select %w(osm_id barrier), :table => [:line, :polygon], :zoom => "16-", :sql => "barrier = 'fence'"
      select %w(osm_id barrier), :table => [:line, :polygon], :zoom => "16-", :sql => "barrier = 'wall'"
      
      select %w(osm_id boundary admin_level), :table => :polygon, :zoom => "3-", :sql => "boundary = 'administrative' and admin_level = '3'"
      select %w(osm_id boundary admin_level name), :table => :polygon, :zoom => "4-5", :sql => "boundary = 'administrative' and admin_level = '3'"
      select %w(osm_id boundary admin_level), :table => :polygon, :zoom => "4-", :sql => "boundary = 'administrative' and admin_level = '4'"
      select %w(osm_id boundary admin_level name), :table => :polygon, :zoom => "6-10", :sql => "boundary = 'administrative' and admin_level = '4'"
      select %w(osm_id boundary admin_level name), :table => :polygon, :zoom => "10-", :sql => "boundary = 'administrative' and admin_level = '6'"
      
      select %w(osm_id capital population name), :table => :point, :zoom => "3-6", :sql => "capital = 'yes'"
      
      select %w(osm_id building), :table => :polygon, :zoom => "13-", :sql => "building is not null"
      select %w(osm_id building addr:housenumber), :table => :polygon, :zoom => "15-", :sql => "building is not null"
      
      select %w(osm_id highway), :table => :point, :zoom => "16-", :sql => "highway = 'bus_stop'"
      select %w(osm_id highway), :table => :point, :zoom => "13-", :sql => "highway = 'milestone'"
      
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'construction'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'cycleway'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'footway'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'living_street'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "9-13", :sql => "highway = 'motorway_link'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "14-", :sql => "highway = 'motorway_link'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "6-7", :sql => "highway = 'motorway'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "8-", :sql => "highway = 'motorway'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'path'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'pedestrian'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "9-", :sql => "highway = 'primary_link'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "7-", :sql => "highway = 'primary'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "12", :sql => "highway = 'residential'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "13-", :sql => "highway = 'residential'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "12", :sql => "highway = 'road'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "13-", :sql => "highway = 'road'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "12-", :sql => "highway = 'secondary_link'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "9", :sql => "highway = 'secondary'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "10-", :sql => "highway = 'secondary'"
      select %w(osm_id highway service name), :table => [:line, :polygon], :zoom => "12-", :sql => "highway = 'service'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'steps'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "12-", :sql => "highway = 'tertiary_link'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "9-10", :sql => "highway = 'tertiary'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "11-", :sql => "highway = 'tertiary'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "12", :sql => "highway = 'track'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "13-", :sql => "highway = 'track'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "9-13", :sql => "highway = 'trunk_link'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "14-", :sql => "highway = 'trunk_link'"
      select %w(osm_id highway), :table => [:line, :polygon], :zoom => "6-9", :sql => "highway = 'trunk'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "10-", :sql => "highway = 'trunk'"
      select %w(osm_id highway name), :table => [:line, :polygon], :zoom => "14-", :sql => "highway = 'unclassified'"
      
      select %w(osm_id oneway), :table => [:line, :polygon], :zoom => "17-", :sql => "oneway is not null"
      
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'allotments'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'cemetery'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'farm'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'farmland'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'field'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'garages'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "12-", :sql => "landuse = 'grass'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'industrial'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "12-", :sql => "landuse = 'meadow'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'military'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'orchard'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "12-", :sql => "landuse = 'recreation_ground'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'reservoir'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'residential'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "4-9", :sql => "landuse = 'forest'"
      select %w(osm_id landuse), :table => :polygon, :zoom => "4-9", :sql => "landuse = 'wood'"
      select %w(osm_id landuse name), :table => :polygon, :zoom => "10-", :sql => "landuse = 'forest'"
      select %w(osm_id landuse name), :table => :polygon, :zoom => "10-", :sql => "landuse = 'wood'"
      select %w(osm_id landuse name), :table => :polygon, :zoom => "9-", :sql => "landuse = 'nature_reserve'"
      
      select %w(osm_id leisure), :table => :polygon, :zoom => "10-", :sql => "leisure = 'garden'"
      select %w(osm_id leisure), :table => :polygon, :zoom => "10", :sql => "leisure = 'park'"
      select %w(osm_id leisure name), :table => :polygon, :zoom => "11-", :sql => "leisure = 'park'"
      select %w(osm_id leisure), :table => :polygon, :zoom => "12-", :sql => "leisure = 'pitch'"
      select %w(osm_id leisure), :table => :polygon, :zoom => "12-", :sql => "leisure = 'stadium'"
      
      select %w(osm_id natural), :table => :polygon, :zoom => "4-9", :sql => "\"natural\" = 'desert'"
      select %w(osm_id natural name), :table => :polygon, :zoom => "10-", :sql => "\"natural\" = 'desert'"
      select %w(osm_id natural), :table => :polygon, :zoom => "4-", :sql => "\"natural\" = 'forest'"
      select %w(osm_id natural), :table => :polygon, :zoom => "3-", :sql => "\"natural\" = 'glacier'"
      select %w(osm_id natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'grass'"
      select %w(osm_id natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'heath'"
      select %w(osm_id natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'meadow'"
      select %w(osm_id natural ele), :table => :point, :zoom => "3-11", :sql => "\"natural\" = 'peak'"
      select %w(osm_id natural name ele), :table => :point, :zoom => "12-", :sql => "\"natural\" = 'peak'"
      select %w(osm_id natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'scrub'"
      select %w(osm_id natural name), :table => :polygon, :zoom => "5-", :sql => "\"natural\" = 'water'"
      select %w(osm_id natural), :table => :polygon, :zoom => "10-", :sql => "\"natural\" = 'wetland'"
      select %w(osm_id natural), :table => :polygon, :zoom => "4-9", :sql => "\"natural\" = 'wood'"
      select %w(osm_id natural name), :table => :polygon, :zoom => "10-", :sql => "\"natural\" = 'wood'"
      
      select %w(osm_id railway), :table => :line, :zoom => "7-", :sql => "railway = 'rail'"
      select %w(osm_id railway name), :table => :point, :zoom => "9-", :sql => "railway = 'station'"
      select %w(osm_id railway name), :table => :point, :zoom => "16-", :sql => "railway = 'subway_entrance'"
      select %w(osm_id railway), :table => [:line, :polygon], :zoom => "12-", :sql => "railway = 'subway'"
      select %w(osm_id railway), :table => :point, :zoom => "16-", :sql => "railway = 'tram_stop'"
      select %w(osm_id railway), :table => [:line, :polygon], :zoom => "12-", :sql => "railway = 'tram'"
      
      select %w(osm_id shop), :table => :point, :zoom => "17-", :sql => "shop is not null"
      
      select %w(osm_id place population name), :table => :point, :zoom => "6-", :sql => "place = 'city'"
      select %w(osm_id place name), :table => :point, :zoom => "-3", :sql => "place = 'continent'"
      select %w(osm_id place name), :table => :point, :zoom => "2-10", :sql => "place = 'country'"
      select %w(osm_id place name), :table => :point, :sql => "place = 'ocean'"
      select %w(osm_id place name), :table => :point, :sql => "place = 'sea'"
      select %w(osm_id place name), :table => :point, :zoom => "12-", :sql => "place = 'suburb'"

      select %w(osm_id place name), :table => :point, :zoom => "9", :sql => "place = 'hamlet'"
      select %w(osm_id place), :table => :polygon, :zoom => "10-", :sql => "place = 'hamlet'"

      select %w(osm_id place name), :table => :polygon, :zoom => "10-", :sql => "place = 'locality'"
      select %w(osm_id place), :table => :polygon, :zoom => "6-7", :sql => "place = 'town'"
      select %w(osm_id place name population), :table => :polygon, :zoom => "8-", :sql => "place = 'town'"

      select %w(osm_id place name), :table => :point, :zoom => "9", :sql => "place = 'village'"
      select %w(osm_id place), :table => :polygon, :zoom => "10-", :sql => "place = 'village'"
      
      select %w(osm_id tourism), :table => :point, :zoom => "17-", :sql => "tourism = 'hotel'"
      select %w(osm_id tourism), :table => :point, :zoom => "16-", :sql => "tourism = 'zoo'"

      select %w(osm_id waterway), :table => [:line, :polygon], :zoom => "10-12", :sql => "waterway = 'canal'"
      select %w(osm_id waterway name), :table => [:line, :polygon], :zoom => "13-", :sql => "waterway = 'canal'"
      select %w(osm_id waterway name), :table => [:line, :polygon], :zoom => "9-", :sql => "waterway = 'river'"
      select %w(osm_id waterway name), :table => :polygon, :zoom => "5-", :sql => "waterway = 'riverbank'"
      select %w(osm_id waterway name), :table => [:line, :polygon], :zoom => "9-", :sql => "waterway = 'stream'"
      
    end
    
    @osm_writer = OSMWriter.new
    @coastline_writer = CoastlineWriter.new(:geometry => "geom")
    
    @maker = Cover::Maker.new(:scale => 1024, :pairs => [[@coastline_source, @coastline_writer], [@osm_source, @osm_writer]])
    
  end
  
  def setup
    @connection = PG.connect(dbname: ENV["DBNAME"] || "gis")
    
    @osm_source.connection = @connection
    @coastline_source.connection = @connection
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    @maker
  end
  
end

Cover.config = SelectionConfig.new
