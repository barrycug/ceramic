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
        select %w(highway tunnel bridge railway layer), :zoom => "14-", :sql => "highway IN ('minor') OR railway IN ('rail')"
        select %w(highway tunnel bridge railway layer), :zoom => "15-", :sql => "highway IN ('footpath', 'track', 'footway', 'steps', 'pedestrian', 'path', 'cycleway') OR railway IN ('rail', 'tram', 'light_rail', 'narrow_gauge', 'monorail')"
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
      
      # admin

      conditions :table => :roads, :sql => "\"boundary\" = 'administrative'" do
        select %w(boundary admin_level), :zoom => "4-10", :sql => "admin_level in ('2', '3', '4')"
        select %w(boundary admin_level), :zoom => "11-", :sql => "admin_level in ('4', '5', '6')"
        select %w(boundary admin_level), :zoom => "12-", :sql => "admin_level in ('7', '8')"
        select %w(boundary admin_level), :zoom => "13-", :sql => "admin_level in ('9', '10')"
        select %w(boundary admin_level), :zoom => "9-11", :sql => "admin_level <> ''"
      end

      # aerialways

      select %w(aerialway), :table => :line, :zoom => "12-18", :sql => "aerialway is not null"

      # amenity-points

      conditions :table => [:point, :polygon] do
  
        select %w(amenity), :zoom => "16-", :sql => "amenity is not null"
        select %w(shop), :zoom => "17-", :sql => "shop is not null"
        select %w(tourism), :zoom => "16-", :sql => "tourism in ('alpine_hut', 'camp_site', 'caravan_site', 'guest_house', 'hostel', 'hotel', 'motel', 'museum', 'viewpoint', 'bed_and_breakfast', 'information', 'chalet')"
        select %w(highway), :zoom => "16-", :sql => "highway in ('bus_stop', 'traffic_signals', 'ford')"
        select %w(man_made), :zoom => "16-", :sql => "man_made in ('mast', 'water_tower')"
        select %w(historic), :zoom => "16-", :sql => "historic in ('memorial', 'archaeological_site')"
        select %w(waterway lock), :zoom => "15-", :sql => "waterway = 'lock'"
        select %w(lock), :zoom => "15-", :sql => "lock = 'yes'"
        select %w(leisure), :zoom => "16-", :sql => "leisure in ('playground', 'slipway')"
  
        select %w(tourism), :zoom => "13-", :sql => "tourism = 'alpine_hut'"
        select %w(amenity religion), :zoom => "16-", :sql => "amenity = 'place_of_worship'"
        select %w(amenity), :zoom => "15-", :sql => "amenity = 'hospital'"
        select %w(amenity access), :zoom => "15-", :sql => "amenity = 'parking'"
        select %w(man_made), :zoom => "16-", :sql => "shop = 'supermarket'"
  
      end
      
      # amenity-stations

      conditions :table => [:polygon, :point] do
  
        select %w(railway), :zoom => "18-", :sql => "railway = 'subway_entrance'"
  
        select %w(railway), :zoom => "12", :sql => "railway = 'station' and disused <> 'yes'"
        select %w(railway disused), :zoom => "13-", :sql => "railway = 'station'"
        select %w(name), :zoom => "14-", :sql => "railway = 'station'"
  
        select %w(railway aerialway name), :zoom => "14-", :sql => "railway in ('halt', 'tram_stop') or aerialway = 'station'"
  
      end
      
      # amenity-symbols

      conditions :table => [:point, :polygon] do
  
        select %w(aeroway), :zoom => "16-", :sql => "aeroway = 'helipad'"
        select %w(aeroway), :zoom => "9-12", :sql => "aeroway = 'airport'"
        select %w(aeroway), :zoom => "10-12", :sql => "aeroway = 'aerodrome'"
        select %w(railway), :zoom => "14-", :sql => "railway = 'level_crossing'"
        select %w(man_made), :zoom => "15-", :sql => "man_made = 'lighthouse'"
        select %w(natural name ele), :table => :point, :zoom => "11-", :sql => "\"natural\" = 'peak'"
        select %w(natural), :zoom => "11-", :sql => "\"natural\" = 'volcano'"
        select %w(natural), :zoom => "15-", :sql => "\"natural\" = 'cave_entrance'"
        select %w(natural), :zoom => "14-", :sql => "\"natural\" = 'spring'"
        select %w(natural), :zoom => "16-", :sql => "\"natural\" = 'tree'"
  
        select %w(power generator:source man_made), :zoom => "15-", :sql => "power = 'generator' or man_made in ('power_wind', 'windmill')"
  
        select %w(barrier), :zoom => "16-", :sql => "barrier is not null"
        select %w(highway barrier), :zoom => "15-", :sql => "highway = 'gate' or barrier = 'gate'"
  
      end
      
      # citywall
      
      select %w(historic), :table => [:line, :polygon], :zoom => "14-", :sql => "historic in ('citywalls', 'castle_walls')"
      
      # ferry-routes
      
      conditions :table => :line, :sql => "route = 'ferry'" do
        select %w(route), :zoom => "7-"
        select %w(name operator), :zoom => "14-"
      end
      
      # landcover

      conditions :table => :polygon do
  
        select %w(leisure), :zoom => "10-", :sql => "leisure in ('park', 'recreation_ground', 'common', 'garden', 'golf_course')"
        select %w(leisure), :zoom => "13-", :sql => "leisure = 'playground'"
        select %w(leisure), :zoom => "14-", :sql => "leisure = 'swimming_pool'"
  
        select %w(tourism), :zoom => "10-", :sql => "tourism in ('attraction', 'zoo')"
        select %w(tourism), :zoom => "13-", :sql => "tourism in ('camp_site', 'caravan_site', 'picnic_site')"
  
        select %w(landuse amenity religion), :zoom => "10-", :sql => "landuse in ('cemetery', 'grave_yard') or amenity = 'grave_yard'"
  
        select %w(landuse), :zoom => "8-", :sql => "landuse in ('forest', 'wood')"
        select %w(landuse), :zoom => "9-", :sql => "landuse in ('farmyard', 'farm', 'farmland')"
        select %w(landuse), :zoom => "10-", :sql => "landuse in ('residential', 'retail', 'industrial', 'railway', 'field', 'meadow', 'grass', 'allotments', 'recreation_ground', 'conservation', 'commercial', 'brownfield', 'landfill', 'greenfield', 'construction')"
        select %w(landuse), :zoom => "11-", :sql => "landuse in ('village_green', 'quarry', 'vineyard', 'orchard')"
        select %w(landuse), :zoom => "12-", :sql => "landuse = 'garages'"
  
        select %w(military), :zoom => "10-", :sql => "military = 'barracks'"
        select %w(military), :zoom => "9-", :sql => "military = 'danger_area'"
  
        select %w(natural), :zoom => "8-", :sql => "\"natural\" in ('wood', 'desert')"
        select %w(natural), :zoom => "10-", :sql => "\"natural\" in ('field', 'sand', 'heath', 'grassland', 'scrub')"
        select %w(natural), :zoom => "13-", :sql => "\"natural\" in ('beach')"
  
        select %w(power), :zoom => "10-", :sql => "power in ('station', 'generator')"
        select %w(power), :zoom => "13-", :sql => "power = 'sub_station'"
  
        select %w(amenity), :zoom => "10-", :sql => "amenity in ('parking', 'university', 'college', 'school', 'hospital', 'kindergarten')"
  
        select %w(aeroway), :zoom => "12-", :sql => "aeroway in ('apron', 'aerodrome')"
  
        select %w(highway), :zoom => "14-", :sql => "highway in ('services', 'rest_area')"
  
      end

      select %w(man_made), :table => :line, :zoom => "14-", :sql => "man_made = 'cutline'"

      select %w(leisure), :table => :polygon, :zoom => "10-", :sql => "leisure in ('sports_centre','stadium','pitch','track')"
      
      # power

      select %w(power), :table => :line, :zoom => "14-", :sql => "power = 'line'"
      select %w(power), :table => :line, :zoom => "16-", :sql => "power = 'minor_line'"
      select %w(power), :table => :point, :zoom => "14-", :sql => "power = 'tower'"
      select %w(power), :table => :point, :zoom => "16-", :sql => "power = 'pole'"
      
      # water
      
      conditions :table => :line do
  
        select %w(waterway tunnel), :zoom => "13-", :sql => "waterway in ('stream', 'drain', 'ditch')"
  
        select %w(waterway), :zoom => "8-", :sql => "waterway = 'river'"
        select %w(waterway), :zoom => "15-18", :sql => "waterway = 'weir'"
        select %w(waterway), :zoom => "13-", :sql => "waterway = 'wadi'"
  
        select %w(waterway name), :zoom => "12-", :sql => "waterway in ('canal', 'derelict_canal')"
  
        select %w(name), :zoom => "12-", :sql => "waterway = 'river'"
  
        select %w(tunnel), :zoom => "14-", :sql => "waterway in ('canal', 'derelict_canal')"
        select %w(tunnel), :zoom => "14-", :sql => "waterway = 'river'"
        select %w(tunnel), :zoom => "15-", :sql => "waterway in ('stream', 'drain', 'ditch')"
  
      end

      conditions :table => :polygon do
  
        select %w(natural), :zoom => "6-", :sql => "\"natural\" = 'glacier'"
        select %w(waterway), :zoom => "9-", :sql => "waterway in ('dock', 'mill_pond')"
        select %w(landuse), :zoom => "7-", :sql => "landuse in ('basin')"
        select %w(natural), :zoom => "6-", :sql => "\"natural\" in ('lake', 'water', 'reservoir', 'bay')"
        select %w(waterway), :zoom => "6-", :sql => "waterway in ('riverbank')"
        select %w(landuse), :zoom => "6-", :sql => "landuse in ('water')"
        select %w(natural), :zoom => "13-", :sql => "\"natural\" in ('mud', 'marsh', 'wetland')"
        select %w(natural), :zoom => "10-", :sql => "\"natural\" in ('land')"
  
        conditions :sql => "\"natural\" = 'glacier' and building is null" do
          select %w(name), :zoom => "10-", :sql => "way_area >= 10000000"
          select %w(name), :zoom => "11-", :sql => "way_area >= 5000000 and way_area < 10000000"
          select %w(name), :zoom => "12-", :sql => "way_area < 5000000"
        end
  
      end
      
      # water_features

      select %w(waterway name), :table => :line, :zoom => "13-", :sql => "waterway = 'dam'"
      select %w(leisure), :table => :polygon, :zoom => "14-", :sql => "leisure = 'marina'"
      select %w(man_made), :table => [:line, :polygon], :zoom => "11-", :sql => "man_made in ('pier', 'breakwater', 'groyne')"
      select %w(waterway), :table => :point, :zoom => "17-", :sql => "waterway = 'lock_gate'"
      
    end
    
    @writer = Writer.new
    
    @maker = Cover::Maker.new(:scale => 1024, :pairs => [[@osm_source, @writer]])
    
  end
  
  def setup
    @connection = PG.connect(dbname: ENV["DBNAME"] || "gis")
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
