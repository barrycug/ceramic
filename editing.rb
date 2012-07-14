class Basic
  
  def setup
    @connection = PG.connect(dbname: "gis")
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    
    point_source = Cover::Source.new(
      "(select osm_id, way from planet_osm_point) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer
      }
    )
    
    line_source = Cover::Source.new(
      "(select osm_id, way, ST_PointOnSurface(way) as point from planet_osm_line) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :line, :simplify => 16 },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer
      }
    )
    
    polygon_source = Cover::Source.new(
      "(select osm_id, way, ST_PointOnSurface(way) as point from planet_osm_polygon) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :polygon, :simplify => 16 },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer
      }
    )
    
    coastline_source = Cover::Source.new(
      "(select ST_Union(ST_Buffer(geom, 0)) as geom from coastlines where geom && !bbox!) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "geom" => { type: :polygon, :simplify => 16 }
      },
      bbox: "geom"
    )
    
    # Builders
    
    point_builder = Cover::Builder.new do |row|
      {
        "id" => row["osm_id"],
        "type" => "osm",
        "geometry" => row["way"]
      }
    end
    
    line_polygon_builder = Cover::Builder.new do |row|
      if row["way"]["type"] == "GeometryCollection"
        nil
      else
        {
          "id" => row["osm_id"],
          "type" => "osm",
          "geometry" => row["way"],
          "reprpoint" => row["point"]["coordinates"]
        }
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
    
    Cover::Maker.new(scale: 8192) do |index, features|
      
      features.make(coastline_source, coastline_builder)
      
      if index.z >= 13
        features.make(polygon_source, line_polygon_builder)
        features.make(line_source, line_polygon_builder)
        features.make(point_source, point_builder)
      end
  
    end
    
  end

end

Cover.config = Basic.new
