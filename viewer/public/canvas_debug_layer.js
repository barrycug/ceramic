var CanvasDebugLayer = L.TileLayer.Canvas.extend({
  
  options: {},
  
  initialize: function(url, options) {
    L.Util.setOptions(this, options);
    this._url = url;
  },
  
  drawTile: function(canvas, tilePoint, zoom) {
  
    // draw "loading" overlay
  
    var context = canvas.getContext("2d");
  
    context.fillStyle = "rgba(255, 255, 255, 0.5)";
    context.fillRect(0, 0, canvas.width, canvas.height);
  
    // load the tile
  
    var request = new XMLHttpRequest();
    var layer = this;
  
    request.onreadystatechange = function() {
      if (this.readyState == this.DONE) {
        if (this.status == 200 && this.responseText) {
          layer._renderTile(canvas, JSON.parse(this.responseText));
        }
      }
    }
    
    var url = this._url.replace("{x}", tilePoint.x).
                        replace("{y}", tilePoint.y).
                        replace("{z}", zoom);
  
    request.open("GET", url, true);
    request.send();
    
  },
  
  _renderPoint: function(context, coordinates, hue, scale) {

    context.beginPath();

    context.arc(coordinates[0], coordinates[1], 3 / scale, 0, Math.PI * 2);

    context.fillStyle = "hsla(" + hue + ", 100%, 50%, 0.8)";
    context.fill();

  },

  _renderLineString: function(context, coordinates, hue, scale) {

    var i;

    // draw the line

    context.beginPath();

    context.moveTo(coordinates[0][0], coordinates[0][1]);

    for (i = 1; i < coordinates.length; i++) {
      context.lineTo(coordinates[i][0], coordinates[i][1]);
    }

    context.strokeStyle = "hsla(" + hue + ", 90%, 50%, 0.5)";
    context.stroke();

    // draw points

    context.beginPath();

    for (i = 0; i < coordinates.length; i++) {
      context.moveTo(coordinates[i][0] + 2 / scale, coordinates[i][1])
      context.arc(coordinates[i][0], coordinates[i][1], 1 / scale, 0, Math.PI * 2);
    }

    context.fillStyle = "#f00";
    context.fill();

  },

  _renderMultiLineString: function(context, coordinates, hue, scale) {

    var i;

    for (i = 0; i < coordinates.length; i++)
      this._renderLineString(context, coordinates[i], hue, scale);

  },

  _renderPolygon: function(context, coordinates, hue, scale) {

    var i, j, k;

    // draw shape

    context.beginPath();

    for (i = 0; i < coordinates.length; i++) {

      context.moveTo(coordinates[i][0][0], coordinates[i][0][1]);

      for (j = 0; j < coordinates[i].length; j++)
        context.lineTo(coordinates[i][j][0], coordinates[i][j][1]);

    }

    context.fillStyle = "hsla(" + hue + ", 90%, 50%, 0.4)";
    context.fill();

    context.strokeStyle = "hsla(" + hue + ", 90%, 50%, 0.5)";
    context.stroke();

    // draw points

    context.beginPath();

    for (i = 0; i < coordinates.length; i++) {

      for (j = 0; j < coordinates[i].length; j++) {
        context.moveTo(coordinates[i][j][0] + 2 / scale, coordinates[i][j][1])
        context.arc(coordinates[i][j][0], coordinates[i][j][1], 1 / scale, 0, Math.PI * 2);
      }

    }

    context.fillStyle = "#f00";
    context.fill();

  },

  _renderMultiPolygon: function(context, coordinates, hue, scale) {
    
    var i;

    for (i = 0; i < coordinates.length; i++)
      this._renderPolygon(context, coordinates[i], hue, scale);

  },

  _renderTile: function(canvas, tile) {

    var context = canvas.getContext("2d");
    var scale = canvas.width / tile.scale;

    context.clearRect(0, 0, canvas.width, canvas.height);

    // Draw an outline around the tile

    context.lineWidth = 1;

    context.strokeStyle = "rgba(255, 255, 255, 0.5)";
    context.strokeRect(0.5, 0.5, canvas.width, canvas.height);

    // Set scale for features

    context.save();
    context.scale(scale, scale);

    context.lineWidth = 2 / scale;

    // Iterate over features
    
    var i;

    for (i = 0; i < tile.features.length; i++) {
      
      var feature = tile.features[i];
      
      // Render feature
      
      var render;

      if (feature.geometry.type === "Point")
        render = this._renderPoint;
      else if (feature.geometry.type === "LineString")
        render = this._renderLineString;
      else if (feature.geometry.type === "MultiLineString")
        render = this._renderMultiLineString;
      else if (feature.geometry.type === "Polygon")
        render = this._renderPolygon;
      else if (feature.geometry.type === "MultiPolygon")
        render = this._renderMultiPolygon;

      if (typeof feature.id === "undefined")
        render.call(this, context, feature.geometry.coordinates, 45, scale);
      else
        render.call(this, context, feature.geometry.coordinates, feature.id, scale);

    }

    context.restore();

  }
  
});
