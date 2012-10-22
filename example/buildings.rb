scale 1024
margin 0.05

source :postgis, :connection_info => { :dbname => "gis" } do

  table <<-SQL, :geometry_column => "way", :geometry_srid => 900913, :zoom => "16-"
(SELECT
  osm_id,
  way,
  building,
  tags -> 'height' AS height
FROM
  planet_osm_polygon
WHERE
  building IS NOT NULL AND building <> 'no') AS buildings
SQL

end
