Cover
=====

This is a library for building JSON map data tiles.

One use of map data tiles is client-side rendering. [An example map is available](http://data-tiles.mdaines.com/).


Requirements
------------

This library depends mainly on having OpenStreetMap data available in a PostGIS database, imported  with [osm2pgsql](http://wiki.openstreetmap.org/wiki/Osm2pgsql).

For running a tile server with mod_tile and Tirex, a Tirex backend is included, along with example configuration files.


Data tile format
----------------

A data tile is a single JSON object, which must have at least the following members:

- scale, a number
- features, an array of feature objects

A feature object may have the following members:

- geometry, a [GeoJSON](http://www.geojson.org/geojson-spec.html)-like geometry object
- id, a number or string identifier for the feature
- type, a string or number which specifies a category for the feature
- tags, an object whose members are strings or numbers which describe the feature (for OSM data, this would simply be the feature's tags)

A valid feature object may omit the "geometry" object and may include other members. A valid data tile object may include other members.

Geometry objects are similar to GeoJSON geometry objects, but use a local coordinate system similar to HTML Canvas. The origin is at the top-left, with x values extending to the right and y values extending to the bottom. The scale member of the data tile object defines the tile's scale: coordinate values are given relative to this value. Also, vertices in polygons must be ordered using the right-hand-rule.

Features' geometries may be clipped to the bounds of the tile. If a feature has more than one part intersecting with the tile, the "multi" version of its geometry should be used to avoid repeating the feature's tags.


Configuration files
-------------------

Configuration files define what data is in a tileset. The library includes two sample configuration files in `config/`.

* `config/render.rb`

  This configuration includes roads, waterways, places, some types of areas, and buildings from OpenStreetMap. At higher zoom levels, it includes all highway features, amenities, shops, and so on.

* `config/target.rb`

  This configuration includes just IDs and geometry for all OpenStreetMap data at zoom levels 16 and above.


Scripts
-------

For any script, <indices> may be a space-separated list of z/x/y tile indices, or a file containing a list of indices. The bench/ directory includes a few sample index lists.

* `script/debug --config <config> [--center <lat>,<lon>,<zoom>] [--host <host>] [--port <port>]`
  
  Starts a small Sinatra app for debugging a tileset configuration.

* `script/bench --config <config> [--tile <indices>] [--metatile <indices>] [--metatile-size <metatile-size>]`
  
  Builds all the tiles or metatiles specified, measuring wall-clock time and file size.

* `script/gallery --config <config> --tile <incides> [--] <output-path>`
  
  Creates an HTML gallery of tiles in the output path, for generating a preview of a what a given configuration will look like at different sizes.

* `script/render --config <config> (--tile <index> | --metatile <index>) [--metatile-size <metatile-size>] [--] <output-path>`
  
  Renders a single tile or metatile to the output path.

* `script/tirex-backend`

  Allows cover to act as a Tirex backend. This script isn't meant to be invoked directly. See tirex/ for a sample Tirex configuration.


Tile server notes
-----------------

- mod_tile must be configured for JSON tiles using the AddTileMimeConfig directive:

  `AddTileMimeConfig /render/ render js`

- Individual tiles are saved gzipped, so the Content-Encoding header must be set for clients to interpret responses:

  `<Location /render>
    Header set Content-Encoding gzip
  </Location>`
