scale 1024
  
source :postgis do
  
  table "planet_osm_polygon", :geometry_column => "way", :zoom => "15-", :margin => 0.05
  table "planet_osm_line", :geometry_column => "way", :zoom => "15-", :margin => 0.05
  table "planet_osm_point", :geometry_column => "way", :zoom => "15-", :margin => 0.05
  
end
