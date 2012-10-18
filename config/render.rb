scale 1024
margin 0.05

source :selection do
  
  query :line, :geometry => "ST_LineMerge(ST_Collect(way))", :group => true do
    select [:highway, :name, :ref], :zoom => "9-14", :conditions => "highway IN ('motorway')"
    select [:highway, :name, :ref], :zoom => "10-14", :conditions => "highway IN ('trunk')"
    select [:highway, :name, :ref], :zoom => "11-14", :conditions => "highway IN ('primary', 'secondary')"
    select [:highway, :name, :ref], :zoom => "12-14", :conditions => "highway IN ('tertiary', 'trunk_link')"
    select [:highway, :name, :ref], :zoom => "13-14", :conditions => "highway IN ('primary_link', 'secondary_link', 'tertiary_link', 'residential', 'unclassified', 'road')"
    select [:highway, :name, :ref], :zoom => "14", :conditions => "highway IN ('service', 'minor')"
    
    select [:railway], :zoom => "14", :conditions => "railway IN ('rail')"
    
    select [:tunnel, :bridge], :zoom => "12-14", :conditions => "highway IN ('motorway', 'trunk', 'trunk_link', 'primary', 'secondary', 'tertiary')"
    select [:tunnel, :bridge], :zoom => "13-14", :conditions => "highway IN ('primary_link', 'secondary_link', 'tertiary_link', 'residential', 'unclassified', 'road')"
    select [:tunnel, :bridge], :zoom => "14", :conditions => "highway IN ('service', 'minor')"
  end
  
  query :point, :line, :polygon do
    options :zoom => "15-" do
      select [:highway, :tunnel, :bridge, :foot, :bicycle, :horse, :name], :conditions => "highway IS NOT NULL"
      select [:railway, :name], :conditions => "railway IS NOT NULL"
    end
  end
  
  # Waterways, adapted from Toner
  # https://github.com/Citytracking/toner
  
  query :line do
    select [:waterway, :name], :zoom => "8-", :conditions => "waterway = 'river'"
  end
  
  query :polygon do
    select [:waterway, :name], :zoom => "10-", :conditions => "waterway in ('riverbank')"
  
    options :conditions => "\"natural\" in ('water', 'bay') or landuse in ('reservoir')" do
      select [:natural, :waterway, :landuse], :zoom => "8", :conditions => "way_area >=  5000000"
      select [:natural, :waterway, :landuse], :zoom => "9", :conditions => "way_area >=  1000000"
      select [:natural, :waterway, :landuse], :zoom => "10", :conditions => "way_area >= 500000"
      select [:natural, :waterway, :landuse], :zoom => "11", :conditions => "way_area >= 100000"
      select [:natural, :waterway, :landuse], :zoom => "12", :conditions => "way_area >= 500000"
      select [:natural, :waterway, :landuse], :zoom => "13", :conditions => "way_area >= 10000"
      select [:natural, :waterway, :landuse], :zoom => "14", :conditions => "way_area >= 5000"
      select [:natural, :waterway, :landuse], :zoom => "15-"
    end
  end
      
  # Places, adapted from OSM mapnik styles
  # http://svn.openstreetmap.org/applications/rendering/mapnik/
  
  query :point do
    select [:place, :name], :conditions => "place in ('continent', 'ocean', 'sea')"
    select [:place, :name], :zoom => "2-", :conditions => "place in ('country')"
    select [:place, :name], :zoom => "4-", :conditions => "place in ('state')"
    select [:place, :name, :capital, :population], :zoom => "6-", :conditions => "place in ('city', 'metropolis')"
    select [:place, :name, :capital, :population], :zoom => "9-", :conditions => "place in ('town')"
    select [:place, :name, :population], :zoom => "9-", :conditions => "place in ('large_town', 'small_town')"
    select [:place, :name, :population], :zoom => "12-", :conditions => "place in ('suburb', 'village', 'large_village')"
    select [:natural, :ele, :name], :zoom => "12-", :conditions => "\"natural\" = 'peak'"
  end
  
  query :line do
    options :conditions => "boundary = 'administrative'" do
      select [:boundary, :admin_level], :zoom => "4-", :conditions => "admin_level in ('2', '3', '4')"
      select [:boundary, :admin_level], :zoom => "11-", :conditions => "admin_level in ('5', '6')"
      select [:boundary, :admin_level], :zoom => "12-", :conditions => "admin_level in ('7', '8')"
      select [:boundary, :admin_level], :zoom => "13-", :conditions => "admin_level in ('9', '10')"
    end
  end
      
  # Areas, partially adapted from Toner
  # https://github.com/Citytracking/toner
  
  query :polygon do
    options :conditions => "landuse IS NOT NULL" do
      select [:landuse], :zoom => "10", :conditions => "way_area > 500000"
      select [:landuse], :zoom => "11", :conditions => "way_area > 100000"
      select [:landuse], :zoom => "12", :conditions => "way_area > 50000"
      select [:landuse], :zoom => "13", :conditions => "way_area > 10000"
      select [:landuse], :zoom => "14-"
    end
  
    options :conditions => "amenity IS NOT NULL OR \"natural\" IS NOT NULL OR leisure IS NOT NULL" do
      select [:amenity, :natural, :leisure], :zoom => "10", :conditions => "way_area > 500000"
      select [:amenity, :natural, :leisure], :zoom => "11", :conditions => "way_area > 100000"
      select [:amenity, :natural, :leisure], :zoom => "12", :conditions => "way_area > 50000"
      select [:amenity, :natural, :leisure], :zoom => "13", :conditions => "way_area > 10000"
      select [:amenity, :natural, :leisure], :zoom => "14-15"
    end
  end
  
  # High zoom stuff
  
  query :point, :polygon do
    select [:amenity, :shop, :name], :zoom => "16-", :conditions => "amenity IS NOT NULL OR shop IS NOT NULL"
    select [:natural, :leisure], :zoom => "16-", :conditions => "\"natural\" IS NOT NULL OR leisure IS NOT NULL"
  end
  
  query :polygon do
    options :conditions => "building IS NOT NULL" do
      select [:building], :zoom => "14", :conditions => "way_area > 20000"
      select [:building], :zoom => "15-"
    end
  end
  
end
