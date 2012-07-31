class Basic
  
  def setup
    @connection = PG.connect(dbname: "gis")
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    
    # High zoom sources
    
    point_source = Cover::Source.new(
      "(select * from planet_osm_point) as q",
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
    
    line_source = Cover::Source.new(
      "(select *, ST_PointOnSurface(way) as point from planet_osm_line) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :line, simplify: 1 },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore
      }
    )
    
    polygon_source = Cover::Source.new(
      "(select *, ST_PointOnSurface(ST_Buffer(way, 0)) as point from planet_osm_polygon) as q",
      connection: @connection,
      srid: 900913,
      geometry: {
        "way" => { type: :polygon, simplify: 1 },
        "point" => { type: :point }
      },
      bbox: "way",
      convert: {
        "osm_id" => :integer,
        "tags" => :hstore,
        "way_area" => :real
      }
    )
    
    coastline_source = Cover::Source.new(
      "(select ST_Union(ST_Buffer(geom, 0)) as geom from coastlines where geom && !bbox!) as q",
      connection: @connection,
      srid: 3857,
      geometry: {
        "geom" => { type: :polygon, simplify: 1 }
      },
      bbox: "geom"
    )
    
    # Builders
    
    point_builder = Cover::Builder.new do |row|
      
      result = {
        "id" => row["osm_id"],
        "type" => "osm",
        "geometry" => row["way"],
        "tags" => {}
      }
      
      # Add tags as-is if it's a hash
      
      if row["tags"].is_a?(Hash)
        result["tags"].update(row["tags"])
      end
      
      # include other values from the row
      
      row.each do |name, value|
        next if %w(way osm_id tags z_order).include?(name)
        next if value == nil
        
        result["tags"][name] = value
      end
      
      result
      
    end
    
    line_polygon_builder = Cover::Builder.new do |row|
      
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
      
        # Add way_area if present (for polygons)
      
        if row["way_area"]
          result["way_area"] = row["way_area"]
        end
        
        # Add contents of tags if it's a hash
      
        if row["tags"].is_a?(Hash)
          result["tags"].update(row["tags"])
        end
      
        # Include other values from the row
      
        row.each do |name, value|
          next if %w(way osm_id tags point way_area z_order).include?(name)
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
    
    Cover::Maker.new(scale: 8192) do |index, features|
      
      if index.z >= 11
        features.make(coastline_source, coastline_builder)
        features.make(polygon_source, line_polygon_builder)
        features.make(line_source, line_polygon_builder)
        features.make(point_source, point_builder)
      end
  
    end
    
  end

end

Cover.config = Basic.new
