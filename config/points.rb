coordinates :latlon
  
source :postgis, :connection_info => { :dbname => "bc" } do
  
  table "(SELECT osm_id AS id, way FROM planet_osm_point) AS points"
  
end
