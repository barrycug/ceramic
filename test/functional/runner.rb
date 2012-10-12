libdir = File.dirname(__FILE__) + "/../../lib"
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require "stringio"
require "cover"

# Set up test database and import the test data

DBNAME = "cover_test"

if `psql -qAt --list` !~ /^#{DBNAME}\|/
  
  `createdb -E UTF8 #{DBNAME}`
  `psql -f /usr/local/share/postgis/postgis.sql -d #{DBNAME}`
  `psql -f /usr/local/share/postgis/spatial_ref_sys.sql -d #{DBNAME}`
  `psql -c "CREATE EXTENSION hstore;" -d #{DBNAME}`
  
end

`osm2pgsql --slim --host=/tmp --proj=3857 --database=#{DBNAME} --hstore-all data.osm.xml`


# Define a tileset

tileset = Cover::Tileset.build do
  
  scale 1024
  
  source :postgis, :connection_info => { :dbname => DBNAME } do
    table "(SELECT osm_id, way, tags -> 'wood' AS wood FROM planet_osm_polygon) polygons", :geometry_column => "way", :geometry_srid => 3857
    table "planet_osm_line", :geometry_column => "way", :geometry_srid => 3857
    table "planet_osm_point", :geometry_column => "way", :geometry_srid => 3857
  end
  
end


# Output a tile

tileset.setup

index = Cover::Index.new(8, 128, 127)
str = StringIO.new("")
tileset.write(index, str)

puts str.string

tileset.teardown
