# Based on High Road: https://github.com/migurski/HighRoad

class Roads
  
  def setup
    @connection = PG.connect(dbname: "gis")
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    
    # Sources
    
    z10 = Cover::Source.new(
      <<-END,
(SELECT *, ST_PointOnSurface(way) AS point FROM
(SELECT osm_id, way, highway, tunnel, bridge, ref FROM planet_osm_line WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary')) q0
LEFT JOIN
(SELECT osm_id, way, name, ref FROM planet_osm_line WHERE highway IN ('motorway', 'trunk')) q1
USING (osm_id, way)
) q
END
      :connection => @connection,
      :srid => 900913,
      :geometry => {
        "way" => { :type => :line, :simplify => 1 },
        "point" => { :type => :point, :simplify => 1 }
      },
      :bbox => "way",
      :convert => {
        "osm_id" => :integer
      }
    )
    
    z11 = Cover::Source.new(
      <<-END,
(SELECT *, ST_PointOnSurface(way) AS point FROM
(SELECT osm_id, way, highway, tunnel, bridge, ref FROM planet_osm_line WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary', 'tertiary')) q0
LEFT JOIN
(SELECT osm_id, way, name, ref FROM planet_osm_line WHERE highway IN ('motorway', 'trunk')) q1
USING (osm_id, way)
) q
END
      :connection => @connection,
      :srid => 900913,
      :geometry => {
        "way" => { :type => :line, :simplify => 1 },
        "point" => { :type => :point, :simplify => 1 }
      },
      :bbox => "way",
      :convert => {
        "osm_id" => :integer
      }
    )
    
    z12 = Cover::Source.new(
      <<-END,
(SELECT *, ST_PointOnSurface(way) AS point FROM
(SELECT osm_id, way, highway, tunnel, bridge, ref FROM planet_osm_line WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'trunk_link', 'residential', 'unclassified', 'road')) q0
LEFT JOIN
(SELECT osm_id, way, name FROM planet_osm_line WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary')) q1
USING (osm_id, way)
) q
END
      :connection => @connection,
      :srid => 900913,
      :geometry => {
        "way" => { :type => :line, :simplify => 1 },
        "point" => { :type => :point, :simplify => 1 }
      },
      :bbox => "way",
      :convert => {
        "osm_id" => :integer
      }
    )
    
    z13 = Cover::Source.new(
      <<-END,
(SELECT *, ST_PointOnSurface(way) AS point FROM
(SELECT osm_id, way, highway, tunnel, bridge, ref FROM planet_osm_line WHERE highway IN ('motorway', 'motorway_link', 'trunk', 'trunk_link', 'primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'residential', 'unclassified', 'road')) q0
LEFT JOIN
(SELECT osm_id, way, name FROM planet_osm_line WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary', 'tertiary')) q1
USING (osm_id, way)
) q
END
      :connection => @connection,
      :srid => 900913,
      :geometry => {
        "way" => { :type => :line, :simplify => 1 },
        "point" => { :type => :point, :simplify => 1 }
      },
      :bbox => "way",
      :convert => {
        "osm_id" => :integer
      }
    )
    
    z14 = Cover::Source.new(
      <<-END,
(SELECT *, ST_PointOnSurface(way) AS point FROM
(SELECT osm_id, way, highway, railway, tunnel, bridge, layer, ref FROM planet_osm_line WHERE highway IN ('motorway', 'motorway_link', 'trunk', 'trunk_link', 'primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'residential', 'unclassified', 'road', 'minor') OR railway IN ('rail')) q0
LEFT JOIN
(SELECT osm_id, way, name FROM planet_osm_line WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'residential', 'unclassified', 'road')) q1
USING (osm_id, way)
) q
END
      :connection => @connection,
      :srid => 900913,
      :geometry => {
        "way" => { :type => :line, :simplify => 1 },
        "point" => { :type => :point, :simplify => 1 }
      },
      :bbox => "way",
      :convert => {
        "osm_id" => :integer
      }
    )
    
    z15 = Cover::Source.new(
      <<-END,
(SELECT *, ST_PointOnSurface(way) AS point FROM
(SELECT osm_id, way, highway, railway, tunnel, bridge, layer, ref FROM planet_osm_line WHERE highway IN ('motorway', 'motorway_link', 'trunk', 'trunk_link', 'primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'residential', 'unclassified', 'road', 'service', 'minor', 'footpath', 'track', 'footway', 'steps', 'pedestrian', 'path', 'cycleway') OR railway IN ('rail', 'tram', 'light_rail', 'narrow_gauge', 'monorail')) q0
LEFT JOIN
(SELECT osm_id, way, name FROM planet_osm_line WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'residential', 'unclassified', 'road', 'service', 'minor', 'footpath', 'track', 'footway', 'steps', 'pedestrian', 'path', 'cycleway', 'motorway_link', 'trunk_link', 'primary_link', 'secondary_link', 'tertiary_link')) q1
USING (osm_id, way)
) q
END
      :connection => @connection,
      :srid => 900913,
      :geometry => {
        "way" => { :type => :line, :simplify => 1 },
        "point" => { :type => :point, :simplify => 1 }
      },
      :bbox => "way",
      :convert => {
        "osm_id" => :integer
      }
    )
    
    coastline = Cover::Source.new(
      "(select ST_Union(ST_Buffer(geom, 0)) as geom from coastlines where geom && !bbox!) as q",
      connection: @connection,
      srid: 3857,
      geometry: {
        "geom" => { type: :polygon, simplify: 1 }
      },
      bbox: "geom"
    )
    
    # Builders
    
    road_builder = Cover::Builder.new do |row|
      
      if row["way"]["type"] == "GeometryCollection"
        nil
      else
        result = {
          "id" => row["osm_id"],
          "type" => "osm",
          "geometry" => row["way"],
          "reprpoint" => row["point"]["coordinates"],
          "tags" => {}
        }
      
        # Include other values from the row
      
        row.each do |name, value|
          next if %w(way osm_id point).include?(name)
          next if value == nil
          
          result["tags"][name] = value
        end
      
        result
      end
      
    end
    
    coastline_builder = Cover::Builder.new do |row|
      
      if row["geom"]["type"] == "GeometryCollection"
        nil
      else
        {
          "type" => "coastline",
          "geometry" => row["geom"]
        }
      end
      
    end
    
    # Maker
    
    Cover::Maker.new(:scale => 8192) do |index, features|
      
      features.make(coastline, coastline_builder) if index.z >= 10
      
      features.make(z10, road_builder) if index.z == 10
      features.make(z11, road_builder) if index.z == 11
      features.make(z12, road_builder) if index.z == 12
      features.make(z13, road_builder) if index.z == 13
      features.make(z14, road_builder) if index.z == 14
      features.make(z15, road_builder) if index.z >= 15
  
    end
    
  end
  
end

Cover.config = Roads.new
