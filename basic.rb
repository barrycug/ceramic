class Basic
  
  def setup
    @connection = PG.connect(dbname: "gis")
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    
    # Define the "maker", which coordinates querying the database and rendering tiles
    # to have a granularity of 8192. This means that features will have integer
    # coordinates ranging from 0 - 8192.
    
    maker = Cover::Maker.new(granularity: 8192)
    
    # Now define the maker's sources. These are organized by zoom level, and refer to
    # either tables or subqueries. Each source may also define a simplification tolerance,
    # which is a multiple of the width of the tile (in this case, in meters) divided by
    # the granularity. A source must also declare which column is its geometry column,
    # and what the SRID of that geometry column is.

    standard_planet_options = {
      connection: @connection,
      geometry_column: "way",
      geometry_srid: 900913
    }
    
    # Select unsimplified coastline. Since there is a union operation, this is faster
    # if we have an intersection clause in the subquery.

    maker.sources << Cover::Sources::PostGIS.new(
      connection: @connection,
      table: "(select ST_Union(ST_Buffer(geom, 0)) as geom, 'coastline' as \"natural\" from coastlines where geom && !bbox!) as c",
      geometry_column: "geom",
      geometry_type: :polygon,
      geometry_srid: 900913,
      zoom: [14]
    )
    
    # Select everything from the planet import and do not simplify. Here we only use
    # table names since the main query takes care of intersection.
    
    maker.sources << Cover::Sources::PostGIS.new(
      standard_planet_options.merge(
        table: "planet_osm_polygon",
        geometry_type: :polygon,
        zoom: [14]
      )
    )
    
    maker.sources << Cover::Sources::PostGIS.new(
      standard_planet_options.merge(
        table: "planet_osm_line",
        geometry_type: :line,
        zoom: [14]
      )
    )
    
    maker.sources << Cover::Sources::PostGIS.new(
      standard_planet_options.merge(
        table: "planet_osm_point",
        geometry_type: :point,
        zoom: [14]
      )
    )
    
    # Similar to the above coastline query, except that we filter by area and
    # simplify geometry. A "granule" is equal to the width of the tile (in this
    # case, in meters) divided by the granularity setting.

    maker.sources << Cover::Sources::PostGIS.new(
      connection: @connection,
      table: "(select ST_Union(ST_Buffer(geom, 0)) as geom, 'coastline' as \"natural\" from coastlines where geom && !bbox! and ST_Area(geom) > !granule! * !granule! * 32 * 32) as c",
      geometry_column: "geom",
      geometry_type: :polygon,
      geometry_srid: 900913,
      simplify: 16,
      zoom: [10, 12]
    )
    
    # Filter polygons and lines by tag and also by area.

    maker.sources << Cover::Sources::PostGIS.new(
      standard_planet_options.merge(
        table: "(select * from planet_osm_polygon where (\"natural\" in ('water', 'wood', 'land', 'beach', 'bay') or \"landuse\" in ('forest', 'residential') or waterway in ('lake', 'river') or boundary in ('administrative', 'protected_area', 'national_park')) and ST_Area(way) > !granule! * !granule! * 256 * 256) as p",
        geometry_type: :polygon,
        simplify: 16,
        zoom: [10, 12]
      )
    )
    
    maker.sources << Cover::Sources::PostGIS.new(
      standard_planet_options.merge(
        table: "(select * from planet_osm_line where (\"waterway\" = 'river' or highway in ('motorway', 'trunk', 'primary', 'secondary') or admin_level <> '' or route = 'ferry') and ST_Length(way) > !granule! * 64) as p",
        geometry_type: :line,
        simplify: 16,
        zoom: [10, 12]
      )
    )
    
    maker.sources << Cover::Sources::PostGIS.new(
      standard_planet_options.merge(
        table: "(select * from planet_osm_point where place in ('city', 'town') or \"natural\" = 'peak') as p",
        geometry_type: :point,
        zoom: [10, 12]
      )
    )
    
    maker
    
  end

end

Cover.config = Basic.new
