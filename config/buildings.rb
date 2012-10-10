scale 1024
  
source :postgis do
  
  query <<-SQL, :geometry_column => "way", :zoom => "16-", :intersection => false, :margin => 0.05
SELECT
  osm_id,
  way,
  tags -> 'height' AS height
FROM
  planet_osm_polygon
WHERE
  building IS NOT NULL AND building <> 'no'
SQL
    
end
