render-data-tile
================

For rendering data tiles from a PostGIS database imported with osm2pgsql.

On the command line:

  $ ruby maketile.rb {z} {x} {y}

To start the web interface, which allows you to debug tile contents by viewing them overlaid on Mapnik tiles:

  $ ruby map.rb


Notes
-----

Alt- or option-click a tile in the web interface to dump its contents to the JavaScript console.

The database name is hard-coded to "gis", and the start point of the map is hard-coded to the SF bay area.

The tile renderer is based on the following script, which is part of the Kothic project:

  http://code.google.com/p/kothic/source/browse/src/json_getter.py
