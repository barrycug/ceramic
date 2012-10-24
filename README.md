# Ceramic

This project provides a library and set of tools for building GeoJSON map tiles from data in a PostGIS database. It also defines a convention for using GeoJSON to encode geographic data in graphics-oriented applications, like client-side rendering or hit testing.


## Installation

Ceramic is a Rubygem which depends on PostGIS. PostGIS can usually be installed with a package manager. If you're running OS X, you can use [Homebrew](http://mxcl.github.com/homebrew):

    $ brew install postgis

Then, install Ceramic:

    $ gem install ceramic

You may also want to install osm2pgsql for importing data from OpenStreetMap. With Homebrew:

    $ brew install --HEAD osm2pgsql

For other systems, see the [osm2pgsql page](http://wiki.openstreetmap.org/wiki/Osm2pgsql) on the OpenStreetMap wiki for installation instructions.


## The `ceramic` Command-Line Tool

The command-line tool has three subcommands:

* The **`render`** subcommand takes a tileset configuration file and tile indices (either as command-line arguments or from standard input), and outputs rendered tiles to standard output or writes them to disk.

* The **`server`** subcommand takes a tileset configuration file and starts a web server which renders tiles on-demand and provides a web map for debugging.

* The **`expand`** subcommand takes as input a list of zoom levels and tile indices or bounding boxes (either as command-line arguments or from standard input), and outputs the expanded indices.

To prepare a set of rendered tiles, you'd first use the `server` subcommand to debug your tileset configuration, ensuring that the right data appears at the right zoom levels. Then, you'd expand a list of tile indices for the area you want to render and pipe the output into the `render` subcommand.


## Example: A Tourist Map of Victoria, BC

Create a PostGIS-enabled database:

    $ createdb -E UTF8 victoria
    $ createlang plpgsql victoria
    $ psql -f /usr/local/share/postgis/postgis.sql -d victoria
    $ psql -f /usr/local/share/postgis/spatial_ref_sys.sql -d victoria

Download data from OpenStreetMap and import it using osm2pgsql:

    $ wget -O victoria.osm.xml http://api.openstreetmap.org/api/0.6/map?bbox=-123.3956,48.4044,-123.3199,48.4516
    $ osm2pgsql --proj=3857 --slim --host=/tmp --database=victoria victoria.osm.xml
  
Make a tileset configuration file:

    coordinates :latlon
    
    source :postgis, :connection_info => { :dbname => "victoria" } do
    
      table <<-SQL, :geometry_column => "way", :geometry_srid => 3857, :zoom => "15"
    (
      SELECT osm_id, name, amenity, tourism, way
      FROM planet_osm_point
      WHERE amenity IS NOT NULL or tourism IS NOT NULL
    ) AS points
    SQL
    
      table <<-SQL, :geometry_column => "way", :geometry_srid => 3857, :zoom => "15"
    (
      SELECT osm_id, name, amenity, tourism, ST_Centroid(way) AS way
      FROM planet_osm_polygons
      WHERE amenity IS NOT NULL or tourism IS NOT NULL
    ) AS centers
    SQL
      
    end

To test the config file, start the server:

    $ ceramic server victoria.rb

Then, open the debugging map in your browser to verify that the tileset configuration works.

    http://localhost:3857/#15/48.4241/-123.3709
  
Render tiles for the downloaded area. We'll expand tiles indices at zoom level 15 for the area we downloaded, and pipe them into the `render` subcommand to render each index. The resulting tiles will be saved in a z/x/y directory structure and wrapped a JSONP callback.

    $ ceramic expand --zoom 15 -- -123.3956,48.4044,-123.3199,48.4516 | ceramic render victoria.rb --callback tileDidLoad --path ./tiles/%z/%x/%y.json

The tiles will look something like this:

    tileDidLoad(15,5152,11329,{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[-123.3950185,48.4444455]},"properties":{"osm_id":"1804301500","tourism":"viewpoint"}}, ... ]})


## Tileset Configuration Files

These use a small DSL for defining a Ceramic::Tileset object. Some examples can be found in the example/ directory.


## Coordinate Conventions

A tileset may use one of two conventions for coordinates, specified by the :latlon and :tile values for the tileset's #coordinates attribute.

When using the :latlon convention, coordinates are given using [the default GeoJSON CRS](http://www.geojson.org/geojson-spec.html#coordinate-reference-system-objects), "a geographic coordinate reference system, using the WGS84 datum, and with longitude and latitude units of decimal degrees".

When using the :tile convention (the default), coordinates are given as spherical mercator meters relative to the top-left of the tile, and scaled to the value of the tileset's #scale attribute. This allows features to be easily drawn with the HTML5 Canvas API, or transformed into SVG.
