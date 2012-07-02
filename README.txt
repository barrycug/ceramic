This repository contains scripts for building
"data tiles" which contain geographic data.


basic.rb
build_california_tileset.rb
---------------------------

This is a configuration file and a script which builds
an MBTiles tileset database for the state of California.
Tile data is compressed with gzip, so the "format"
metadata value will be written as "js.gz".

The script assumes that planet data has been imported
with osm2pgsql, and that coastline data is available
in a "coastlines" table.

Coastline data may be imported as follows:

  wget http://tile.openstreetmap.org/processed_p.tar.bz2
  tar xjf processed_p.tar.bz2
  shp2pgsql -s 900913 -I processed_p.shp coastlines | psql -d gis > /dev/null


script/debug
------------

This is a web interface for debugging configuration
files and viewing tilesets. It draws data tiles as an
overlay on Mapnik tiles and allows close visual
inspection of individual tiles.

When started with the --config option, it loads the
specified config file and prepares tiles dynamically.

  $ script/debug --config basic.rb

When started with the --tileset option, it opens the
specified MBTiles tileset database and serves static
tiles from that. It can handle compressed tiles (when
the "format" metadata value is "js.gz") but does not
do content negotiation.

  $ script/debug --tileset california.mbtiles

Initial map center and zoom can be specified:

  $ script/debug --tileset california.mbtiles \
                 --center 37.74,-122.35,10

The root path shows the map. If you option- or alt-
click on a tile, its data will be dumped to the
console.

Individual tiles (with JSONP callback wrappers) are
served from paths like this:

  /10/163/395

An individual tile may be drawn by itself in detail
by using a path like this:

  /10/163/395/inspect

Colors in the debug web interface are based on
features' "osm_id" property. In the absence of such
a property (such as coastlines), features are shown
with an orangish color.


script/tile
-----------

Given a config file and a tile index, builds an
individual tile.

  $ script/tile --config basic.rb 10/163/395
