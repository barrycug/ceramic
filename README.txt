render-data-tile
================

For rendering data tiles from a PostGIS database imported with osm2pgsql.

On the command line:

  $ ruby maketile.rb {z} {x} {y}

To start the web interface, which allows you to debug tiles:

  $ ruby map.rb


Notes
-----

The database name is hard-coded to "gis", and the start point of the map is hard-coded to the SF bay area.
