require "json"

class RenderConfig

  class OSMWriter
  
    def write_feature(row, io)
      io << "{"
      io << "\"type\":\"osm\","
      io << "\"id\":#{row["osm_id"]}," if row["osm_id"]
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
      
      # Highways and railways, adapted from High Road
      # https://github.com/migurski/HighRoad/
      
      query :line, :geometry => "ST_LineMerge(ST_Collect(way))", :group => true do
        select [:highway, :name, :ref], :zoom => "9-14", :sql => "highway IN ('motorway')"
        select [:highway, :name, :ref], :zoom => "10-14", :sql => "highway IN ('trunk')"
        select [:highway, :name, :ref], :zoom => "11-14", :sql => "highway IN ('primary', 'secondary')"
        select [:highway, :name, :ref], :zoom => "12-14", :sql => "highway IN ('tertiary', 'trunk_link')"
        select [:highway, :name, :ref], :zoom => "13-14", :sql => "highway IN ('primary_link', 'secondary_link', 'tertiary_link', 'residential', 'unclassified', 'road')"
        select [:highway, :name, :ref], :zoom => "14", :sql => "highway IN ('service', 'minor')"
        
        select [:railway], :zoom => "14", :sql => "railway IN ('rail')"
        
        select [:tunnel, :bridge], :zoom => "12-14", :sql => "highway IN ('motorway', 'trunk', 'trunk_link', 'primary', 'secondary', 'tertiary')"
        select [:tunnel, :bridge], :zoom => "13-14", :sql => "highway IN ('primary_link', 'secondary_link', 'tertiary_link', 'residential', 'unclassified', 'road')"
        select [:tunnel, :bridge], :zoom => "14", :sql => "highway IN ('service', 'minor')"
      end
      
      query :point, :line, :polygon do
        options :zoom => "15-" do
          select [:highway, :tunnel, :bridge, :foot, :bicycle, :horse, :name], :sql => "highway IS NOT NULL"
          select [:railway, :name], :sql => "railway IS NOT NULL"
        end
      end
      
      # Waterways, adapted from Toner
      # https://github.com/Citytracking/toner
      
      query :line do
        select [:waterway, :name], :zoom => "8-", :sql => "waterway = 'river'"
      end
      
      query :polygon do
        select [:waterway, :name], :zoom => "10-", :sql => "waterway in ('riverbank')"
      
        options :sql => "\"natural\" in ('water', 'bay') or landuse in ('reservoir')" do
          select [:natural, :waterway, :landuse], :zoom => "8", :sql => "way_area >=  5000000"
          select [:natural, :waterway, :landuse], :zoom => "9", :sql => "way_area >=  1000000"
          select [:natural, :waterway, :landuse], :zoom => "10", :sql => "way_area >= 500000"
          select [:natural, :waterway, :landuse], :zoom => "11", :sql => "way_area >= 100000"
          select [:natural, :waterway, :landuse], :zoom => "12", :sql => "way_area >= 500000"
          select [:natural, :waterway, :landuse], :zoom => "13", :sql => "way_area >= 10000"
          select [:natural, :waterway, :landuse], :zoom => "14", :sql => "way_area >= 5000"
          select [:natural, :waterway, :landuse], :zoom => "15-"
        end
      end
          
      # Places, adapted from OSM mapnik styles
      # http://svn.openstreetmap.org/applications/rendering/mapnik/
      
      query :point do
        select [:place, :name], :sql => "place in ('continent', 'ocean', 'sea')"
        select [:place, :name], :zoom => "2-", :sql => "place in ('country')"
        select [:place, :name], :zoom => "4-", :sql => "place in ('state')"
        select [:place, :name, :capital, :population], :zoom => "6-", :sql => "place in ('city', 'metropolis')"
        select [:place, :name, :capital, :population], :zoom => "9-", :sql => "place in ('town')"
        select [:place, :name, :population], :zoom => "9-", :sql => "place in ('large_town', 'small_town')"
        select [:place, :name, :population], :zoom => "12-", :sql => "place in ('suburb', 'village', 'large_village')"
        select [:natural, :ele, :name], :zoom => "12-", :sql => "\"natural\" = 'peak'"
      end
      
      query :line do
        options :sql => "boundary = 'administrative'" do
          select [:boundary, :admin_level], :zoom => "4-", :sql => "admin_level in ('2', '3', '4')"
          select [:boundary, :admin_level], :zoom => "11-", :sql => "admin_level in ('5', '6')"
          select [:boundary, :admin_level], :zoom => "12-", :sql => "admin_level in ('7', '8')"
          select [:boundary, :admin_level], :zoom => "13-", :sql => "admin_level in ('9', '10')"
        end
      end
          
      # Areas, partially adapted from Toner
      # https://github.com/Citytracking/toner
      
      query :polygon do
        options :sql => "landuse IS NOT NULL" do
          select [:landuse], :zoom => "10", :sql => "way_area > 500000"
          select [:landuse], :zoom => "11", :sql => "way_area > 100000"
          select [:landuse], :zoom => "12", :sql => "way_area > 50000"
          select [:landuse], :zoom => "13", :sql => "way_area > 10000"
          select [:landuse], :zoom => "14-"
        end
      
        options :sql => "amenity IS NOT NULL OR \"natural\" IS NOT NULL OR leisure IS NOT NULL" do
          select [:amenity, :natural, :leisure], :zoom => "10", :sql => "way_area > 500000"
          select [:amenity, :natural, :leisure], :zoom => "11", :sql => "way_area > 100000"
          select [:amenity, :natural, :leisure], :zoom => "12", :sql => "way_area > 50000"
          select [:amenity, :natural, :leisure], :zoom => "13", :sql => "way_area > 10000"
          select [:amenity, :natural, :leisure], :zoom => "14-15"
        end
      end
      
      # High zoom stuff
      
      query :point, :polygon do
        select [:amenity, :shop, :name], :zoom => "16-", :sql => "amenity IS NOT NULL OR shop IS NOT NULL"
        select [:natural, :leisure], :zoom => "16-", :sql => "\"natural\" IS NOT NULL OR leisure IS NOT NULL"
      end
      
      query :polygon do
        options :sql => "building IS NOT NULL" do
          select [:building], :zoom => "14", :sql => "way_area > 20000"
          select [:building], :zoom => "15-"
        end
      end
      
    end
    
    @osm_writer = OSMWriter.new
    
    @maker = Cover::Maker.new(:scale => 1024, :pairs => [[@osm_source, @osm_writer]])
    
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

Cover.config = RenderConfig.new
