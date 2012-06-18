render-data-tile
================

For rendering data tiles from a PostGIS database imported with osm2pgsql.

To render a single tile to standard output:

  $ ruby maketile.rb --tile=<z>/<x>/<y> \
                     --config=everything.yml \
                     --database=gis

To render a list of tile indices (one per line):

  $ ruby maketile.rb --tiles=indices.txt \
                     --config=everything.yml \
                     --database=gis \
                     --output=./tiles/%z/%x/%y.js

To start the web interface (in the debug directory), which allows you to debug tile contents by viewing them overlaid on Mapnik tiles:

  $ DATABASE=gis ruby debug.rb

In the web interface, option- or alt-click any tile to dump its contents to the JavaScript console.

To specify a start point for the web interface, use the ZOOM and CENTER environment variables, for example:

  $ DATABASE=gis ZOOM=13 CENTER=37.48,-122.44 debug.rb
  
Otherwise, default values will be used.
