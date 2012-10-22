coordinates :latlon
  
source :postgis, :connection_info => { :dbname => "gis" } do
  
  table "(SELECT osm_id AS id, way FROM planet_osm_point) AS points"
  
end
