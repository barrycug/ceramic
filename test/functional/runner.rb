libdir = File.dirname(__FILE__) + "/../../lib"
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require "stringio"
require "ceramic"

# Set up test database and import the test data

dbname = "ceramic_test"

if `psql -qAt --list` !~ /^#{dbname}\|/
  
  `createdb -E UTF8 #{dbname}`
  `psql -f /usr/local/share/postgis/postgis.sql -d #{dbname}`
  `psql -f /usr/local/share/postgis/spatial_ref_sys.sql -d #{dbname}`
  `psql -c "CREATE EXTENSION hstore;" -d #{dbname}`
  
end

`osm2pgsql --slim --host=/tmp --proj=3857 --database=#{dbname} --hstore data.osm.xml`


# Define a tileset

tileset = Ceramic::Tileset.build do
  
  scale 1024
  
  source :postgis, :connection_info => { :dbname => dbname } do
    table "(SELECT osm_id, way, tags -> 'wood' AS wood FROM planet_osm_polygon) polygons", :geometry_column => "way", :geometry_srid => 3857
    table "planet_osm_line", :geometry_column => "way", :geometry_srid => 3857
    table "planet_osm_point", :geometry_column => "way", :geometry_srid => 3857
  end
  
end


# Output a tile

tileset.setup

index = Ceramic::Index.new(8, 128, 127)
str = StringIO.new("")
tileset.write(index, str)

puts str.string

tileset.teardown
