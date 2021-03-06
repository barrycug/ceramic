var CanvasDebugLayer = L.TileLayer.Canvas.extend({
  
  options: {},
  
  initialize: function(url, options) {
    L.Util.setOptions(this, options);
    this._url = url;
  },
  
  drawTile: function(canvas, tilePoint, zoom) {
    
    var layer = this;
  
    // draw "loading" overlay
  
    var context = canvas.getContext("2d");
  
    context.fillStyle = "rgba(255, 255, 255, 0.5)";
    context.fillRect(0, 0, canvas.width, canvas.height);
  
    // load the tile
  
    var request = new XMLHttpRequest();
  
    request.onreadystatechange = function() {
      
      if (this.readyState == this.DONE) {
        if (this.status == 200 && this.responseText) {
          
          var tile = JSON.parse(this.responseText);
          
          if (typeof tile.crs === "undefined")
            CanvasDebugLayer.projectTile(tile, tilePoint, zoom, layer.options.tileSize);
          
          DebugRender.renderTile(canvas, tile);
          
        }
      }
      
    }
    
    var url = this._url.replace("{x}", tilePoint.x).
                        replace("{y}", tilePoint.y).
                        replace("{z}", zoom);
  
    request.open("GET", url, true);
    request.send();
    
  }
  
});

CanvasDebugLayer.EXTENT = 2 * Math.PI * 6378137;
CanvasDebugLayer.ORIGIN = -(CanvasDebugLayer.EXTENT / 2.0);

CanvasDebugLayer.projectTile = function(tile, tilePoint, zoom, tileSize) {
  
  tile.scale = tileSize;
  
  // find the tile's left and top in spherical mercator
  
  var scale = Math.pow(2, zoom);
  var size = this.EXTENT / scale;
  var left = this.ORIGIN + (tilePoint.x * size);
  var top = this.ORIGIN + ((scale - tilePoint.y) * size) - size;
  
  function projectPoint(coordinates) {
    
    var point = L.CRS.EPSG3857.project(new L.LatLng(coordinates[1], coordinates[0]));
    
    coordinates[0] = ((point.x - left) / size) * tile.scale;
    coordinates[1] = tile.scale - (((point.y - top) / size) * tile.scale);
    
  }
  
  function projectCoordinates(coordinates, dimension) {
    
    var i;
    
    if (dimension === 1) {
      projectPoint(coordinates);
    } else {
      for (i = 0; i < coordinates.length; i++)
        projectCoordinates(coordinates[i], dimension - 1);
    }
    
  }
  
  function projectGeometry(geometry) {
    
    var i;
    
    switch (geometry.type) {
      case "Point":
        projectCoordinates(geometry.coordinates, 1);
        break;
      case "MultiPoint":
      case "LineString":
        projectCoordinates(geometry.coordinates, 2);
        break;
      case "MultiLineString":
      case "Polygon":
        projectCoordinates(geometry.coordinates, 3);
        break;
      case "MultiPolygon":
        projectCoordinates(geometry.coordinates, 4);
        break;
      case "FeatureCollection":
        for (i = 0; i < geometry.geometries.length; i++)
          projectGeometry(geometry.geometries[i]);
        break;
    }
    
  }
  
  
  var i = 0;
  
  for (i = 0; i < tile.features.length; i++)
    projectGeometry(tile.features[i].geometry);

}
