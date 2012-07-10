class Basic
  
  def setup
    @connection = PG.connect(dbname: "gis")
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    
    # High zoom sources
    
    high_zoom_point_source = Cover::Source.new(
      "(select osm_id, way, tags from planet_osm_point) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore
      }
    )
    
    high_zoom_line_source = Cover::Source.new(
      "(select osm_id, way, tags, ST_PointOnSurface(way) as point from planet_osm_line) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :line },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore
      }
    )
    
    high_zoom_polygon_source = Cover::Source.new(
      "(select osm_id, way, tags, ST_PointOnSurface(ST_Buffer(way, 0)) as point from planet_osm_polygon) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :polygon },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore
      }
    )
    
    high_zoom_coastline_source = Cover::Source.new(
      "(select ST_Union(ST_Buffer(geom, 0)) as geom from coastlines where geom && !bbox!) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "geom" => { type: :polygon }
      },
      bbox: "geom"
    )
    
    # Medium zoom sources
    
    medium_zoom_point_source = Cover::Source.new(
      "(select osm_id, way, slice(tags, ARRAY['place', 'natural', 'name']) as tags from planet_osm_point where place in ('city', 'town') or \"natural\" = 'peak') as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore
      }
    )
    
    medium_zoom_line_source = Cover::Source.new(
      "(select osm_id, way, slice(tags, ARRAY['waterway', 'highway', 'admin_level', 'route', 'name']) as tags, ST_PointOnSurface(way) as point from planet_osm_line where (\"waterway\" = 'river' or highway in ('motorway', 'trunk', 'primary', 'secondary') or admin_level <> '' or route = 'ferry') and ST_Length(way) > :unit::float * 64) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :line, simplify: 16 },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore
      }
    )
    
    medium_zoom_polygon_source = Cover::Source.new(
      "(select osm_id, way, slice(tags, ARRAY['natural', 'landuse', 'waterway', 'boundary', 'name']) as tags, ST_PointOnSurface(ST_Buffer(way, 0)) as point from planet_osm_polygon where (\"natural\" in ('water', 'wood', 'land', 'beach', 'bay') or \"landuse\" in ('forest', 'residential') or waterway in ('lake', 'river') or boundary in ('administrative', 'protected_area', 'national_park')) and ST_Area(way) > :unit::float * :unit::float * 256 * 256) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :polygon, simplify: 16 },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore
      }
    )
    
    # Low zoom sources
    
    low_zoom_coastline_source = Cover::Source.new(
      "(select ST_Union(ST_Buffer(geom, 0)) as geom from coastlines where geom && !bbox! and ST_Area(geom) > :unit::float * :unit::float * 32 * 32) as c",
      connection: @connection,
      srid: 900913,
      geometry: {
        "geom" => { type: :polygon, simplify: 16 }
      },
      bbox: "geom"
    )
    
    # Builders
    
    point_builder = Cover::Builder.new do |row|
      {
        "id" => row["osm_id"],
        "type" => "osm",
        "tags" => row["tags"],
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
          "tags" => row["tags"],
          "geometry" => row["way"],
          "kothic:reprpoint" => row["point"]["coordinates"]
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
      
      if index.z >= 11
        
        features.make(high_zoom_coastline_source, coastline_builder)
        features.make(high_zoom_polygon_source, line_polygon_builder)
        features.make(high_zoom_line_source, line_polygon_builder)
        features.make(high_zoom_point_source, point_builder)
        
      elsif index.z >= 9
        
        features.make(low_zoom_coastline_source, coastline_builder)
        features.make(medium_zoom_polygon_source, line_polygon_builder)
        features.make(medium_zoom_line_source, line_polygon_builder)
        features.make(medium_zoom_point_source, point_builder)
        
      else
        
        features.make(low_zoom_coastline_source, coastline_builder)
        
      end
  
    end
    
  end

end

Cover.config = Basic.new
