# Ceramic

This project provides a set of tools for building GeoJSON map tiles from data in a PostGIS database. It also defines a convention for using GeoJSON to encode geographic data in graphics-oriented applications, like client-side rendering or hit testing.


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

    $ cat victoria.rb
    coordinates :latlon
    
    source :postgis, :connection_info => { :dbname => "victoria" } do
      table "(select osm_id, name, amenity, tourism, way from planet_osm_point where amenity is not null or tourism is not null) as points", :geometry_column => "way", :geometry_srid => 3857, :zoom => "15"
      table "(select osm_id, name, amenity, tourism, ST_Centroid(way) as way from planet_osm_polygon where amenity is not null or tourism is not null) as points", :geometry_column => "way", :geometry_srid => 3857, :zoom => "15"
    end

To test the config file, start the server:

    $ ceramic server victoria.rb

Then, open your browser to:

    http://localhost:3857/#15/48.4241/-123.3709
  
Finally, render tiles for the downloaded area:

    $ ceramic expand -z 15 -123.3956,48.4044,-123.3199,48.4516 | ceramic render victoria.rb --path ./tiles/%z/%x/%y.json


## Tileset Configuration Files



## The "Tile" Coordinate System

