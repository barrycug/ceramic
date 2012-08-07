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
      
      select %w(aeroway name), :table => :point, :zoom => "10-", :sql => "aeroway = 'aerodrome'"
      select %w(aeroway), :table => :polygon, :zoom => "13-", :sql => "aeroway = 'aerodrome'"

      select %w(amenity), :table => :point, :zoom => "15-", :sql => "amenity = 'bus_station'"
      select %w(amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'cinema'"
      select %w(amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'courthouse'"
      select %w(amenity), :table => :point, :zoom => "15-", :sql => "amenity = 'fuel'"
      select %w(amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'kindergarten'"
      select %w(amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'library'"
      select %w(amenity), :table => :point, :zoom => "15-", :sql => "amenity = 'museum'"
      select %w(amenity), :table => [:point, :polygon], :zoom => "15-", :sql => "amenity = 'parking'"
      select %w(amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'pharmacy'"
      select %w(amenity name religion), :table => [:point, :polygon], :zoom => "14-", :sql => "amenity = 'place_of_worship'"
      select %w(amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'post_office'"
      select %w(amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'restaurant'"
      select %w(amenity), :table => :point, :zoom => "17-", :sql => "amenity = 'school'"
      select %w(amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'theatre'"
      select %w(amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'toilets'"
      select %w(amenity), :table => :point, :zoom => "16-", :sql => "amenity = 'university'"
      
      select %w(barrier), :table => [:line, :polygon], :zoom => "16-", :sql => "barrier = 'fence'"
      select %w(barrier), :table => [:line, :polygon], :zoom => "16-", :sql => "barrier = 'wall'"
      
      select %w(boundary admin_level), :table => :polygon, :zoom => "3-", :sql => "boundary = 'administrative' and admin_level = '3'"
      select %w(boundary admin_level name), :table => :polygon, :zoom => "4-5", :sql => "boundary = 'administrative' and admin_level = '3'"
      select %w(boundary admin_level), :table => :polygon, :zoom => "4-", :sql => "boundary = 'administrative' and admin_level = '4'"
      select %w(boundary admin_level name), :table => :polygon, :zoom => "6-10", :sql => "boundary = 'administrative' and admin_level = '4'"
      select %w(boundary admin_level name), :table => :polygon, :zoom => "10-", :sql => "boundary = 'administrative' and admin_level = '6'"
      
      select %w(capital population name), :table => :point, :zoom => "3-6", :sql => "capital = 'yes'"
      
      select %w(building), :table => :polygon, :zoom => "13-", :sql => "building is not null"
      select %w(building addr:housenumber), :table => :polygon, :zoom => "15-", :sql => "building is not null"
      
      select %w(highway), :table => :point, :zoom => "16-", :sql => "highway = 'bus_stop'"
      select %w(highway), :table => :point, :zoom => "13-", :sql => "highway = 'milestone'"
      
      select %w(highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'construction'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'cycleway'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'footway'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'living_street'"
      select %w(highway), :table => [:line, :polygon], :zoom => "9-13", :sql => "highway = 'motorway_link'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "14-", :sql => "highway = 'motorway_link'"
      select %w(highway), :table => [:line, :polygon], :zoom => "6-7", :sql => "highway = 'motorway'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "8-", :sql => "highway = 'motorway'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'path'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'pedestrian'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "9-", :sql => "highway = 'primary_link'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "7-", :sql => "highway = 'primary'"
      select %w(highway), :table => [:line, :polygon], :zoom => "12", :sql => "highway = 'residential'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "13-", :sql => "highway = 'residential'"
      select %w(highway), :table => [:line, :polygon], :zoom => "12", :sql => "highway = 'road'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "13-", :sql => "highway = 'road'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "12-", :sql => "highway = 'secondary_link'"
      select %w(highway), :table => [:line, :polygon], :zoom => "9", :sql => "highway = 'secondary'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "10-", :sql => "highway = 'secondary'"
      select %w(highway service name), :table => [:line, :polygon], :zoom => "12-", :sql => "highway = 'service'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "15-", :sql => "highway = 'steps'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "12-", :sql => "highway = 'tertiary_link'"
      select %w(highway), :table => [:line, :polygon], :zoom => "9-10", :sql => "highway = 'tertiary'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "11-", :sql => "highway = 'tertiary'"
      select %w(highway), :table => [:line, :polygon], :zoom => "12", :sql => "highway = 'track'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "13-", :sql => "highway = 'track'"
      select %w(highway), :table => [:line, :polygon], :zoom => "9-13", :sql => "highway = 'trunk_link'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "14-", :sql => "highway = 'trunk_link'"
      select %w(highway), :table => [:line, :polygon], :zoom => "6-9", :sql => "highway = 'trunk'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "10-", :sql => "highway = 'trunk'"
      select %w(highway name), :table => [:line, :polygon], :zoom => "14-", :sql => "highway = 'unclassified'"
      
      select %w(oneway), :table => [:line, :polygon], :zoom => "17-", :sql => "oneway is not null"
      
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'allotments'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'cemetery'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'farm'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'farmland'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'field'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'garages'"
      select %w(landuse), :table => :polygon, :zoom => "12-", :sql => "landuse = 'grass'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'industrial'"
      select %w(landuse), :table => :polygon, :zoom => "12-", :sql => "landuse = 'meadow'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'military'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'orchard'"
      select %w(landuse), :table => :polygon, :zoom => "12-", :sql => "landuse = 'recreation_ground'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'reservoir'"
      select %w(landuse), :table => :polygon, :zoom => "10-", :sql => "landuse = 'residential'"
      select %w(landuse), :table => :polygon, :zoom => "4-9", :sql => "landuse = 'forest'"
      select %w(landuse), :table => :polygon, :zoom => "4-9", :sql => "landuse = 'wood'"
      select %w(landuse name), :table => :polygon, :zoom => "10-", :sql => "landuse = 'forest'"
      select %w(landuse name), :table => :polygon, :zoom => "10-", :sql => "landuse = 'wood'"
      select %w(landuse name), :table => :polygon, :zoom => "9-", :sql => "landuse = 'nature_reserve'"
      
      select %w(leisure), :table => :polygon, :zoom => "10-", :sql => "leisure = 'garden'"
      select %w(leisure), :table => :polygon, :zoom => "10", :sql => "leisure = 'park'"
      select %w(leisure name), :table => :polygon, :zoom => "11-", :sql => "leisure = 'park'"
      select %w(leisure), :table => :polygon, :zoom => "12-", :sql => "leisure = 'pitch'"
      select %w(leisure), :table => :polygon, :zoom => "12-", :sql => "leisure = 'stadium'"
      
      select %w(natural), :table => :polygon, :zoom => "4-9", :sql => "\"natural\" = 'desert'"
      select %w(natural name), :table => :polygon, :zoom => "10-", :sql => "\"natural\" = 'desert'"
      select %w(natural), :table => :polygon, :zoom => "4-", :sql => "\"natural\" = 'forest'"
      select %w(natural), :table => :polygon, :zoom => "3-", :sql => "\"natural\" = 'glacier'"
      select %w(natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'grass'"
      select %w(natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'heath'"
      select %w(natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'meadow'"
      select %w(natural ele), :table => :point, :zoom => "3-11", :sql => "\"natural\" = 'peak'"
      select %w(natural name ele), :table => :point, :zoom => "12-", :sql => "\"natural\" = 'peak'"
      select %w(natural), :table => :polygon, :zoom => "12-", :sql => "\"natural\" = 'scrub'"
      select %w(natural name), :table => :polygon, :zoom => "5-", :sql => "\"natural\" = 'water'"
      select %w(natural), :table => :polygon, :zoom => "10-", :sql => "\"natural\" = 'wetland'"
      select %w(natural), :table => :polygon, :zoom => "4-9", :sql => "\"natural\" = 'wood'"
      select %w(natural name), :table => :polygon, :zoom => "10-", :sql => "\"natural\" = 'wood'"
      
      select %w(railway), :table => :line, :zoom => "7-", :sql => "railway = 'rail'"
      select %w(railway name), :table => :point, :zoom => "9-", :sql => "railway = 'station'"
      select %w(railway name), :table => :point, :zoom => "16-", :sql => "railway = 'subway_entrance'"
      select %w(railway), :table => [:line, :polygon], :zoom => "12-", :sql => "railway = 'subway'"
      select %w(railway), :table => :point, :zoom => "16-", :sql => "railway = 'tram_stop'"
      select %w(railway), :table => [:line, :polygon], :zoom => "12-", :sql => "railway = 'tram'"
      
      select %w(shop), :table => :point, :zoom => "17-", :sql => "shop is not null"
      
      select %w(place population name), :table => :point, :zoom => "6-", :sql => "place = 'city'"
      select %w(place name), :table => :point, :zoom => "-3", :sql => "place = 'continent'"
      select %w(place name), :table => :point, :zoom => "2-10", :sql => "place = 'country'"
      select %w(place name), :table => :point, :sql => "place = 'ocean'"
      select %w(place name), :table => :point, :sql => "place = 'sea'"
      select %w(place name), :table => :point, :zoom => "12-", :sql => "place = 'suburb'"

      select %w(place name), :table => :point, :zoom => "9", :sql => "place = 'hamlet'"
      select %w(place), :table => :polygon, :zoom => "10-", :sql => "place = 'hamlet'"

      select %w(place name), :table => :polygon, :zoom => "10-", :sql => "place = 'locality'"
      select %w(place), :table => :polygon, :zoom => "6-7", :sql => "place = 'town'"
      select %w(place name population), :table => :polygon, :zoom => "8-", :sql => "place = 'town'"

      select %w(place name), :table => :point, :zoom => "9", :sql => "place = 'village'"
      select %w(place), :table => :polygon, :zoom => "10-", :sql => "place = 'village'"
      
      select %w(tourism), :table => :point, :zoom => "17-", :sql => "tourism = 'hotel'"
      select %w(tourism), :table => :point, :zoom => "16-", :sql => "tourism = 'zoo'"

      select %w(waterway), :table => [:line, :polygon], :zoom => "10-12", :sql => "waterway = 'canal'"
      select %w(waterway name), :table => [:line, :polygon], :zoom => "13-", :sql => "waterway = 'canal'"
      select %w(waterway name), :table => [:line, :polygon], :zoom => "9-", :sql => "waterway = 'river'"
      select %w(waterway name), :table => :polygon, :zoom => "5-", :sql => "waterway = 'riverbank'"
      select %w(waterway name), :table => [:line, :polygon], :zoom => "9-", :sql => "waterway = 'stream'"
      
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
