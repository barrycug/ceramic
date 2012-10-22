scale 1024
margin 0.05
  
source :postgis, :connection_info => { :dbname => "gis" } do
  
  table "planet_osm_polygon", :zoom => "15-"
  table "planet_osm_line", :zoom => "15-"
  table "planet_osm_point", :zoom => "15-"
  
end
