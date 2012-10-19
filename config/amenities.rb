coordinates :latlon

source :postgis, :connection_info => { :dbname => "bc" } do
  
  table "(SELECT osm_id, name, amenity, way FROM planet_osm_point WHERE amenity IS NOT NULL) AS points", :zoom => "15-"
  table "(SELECT osm_id, name, amenity, ST_Centroid(way) AS way FROM planet_osm_polygon WHERE amenity IS NOT NULL) AS polygons", :zoom => "15-"
  
end
