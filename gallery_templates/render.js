var DebugRender = {
  
  renderPoint: function(context, coordinates, hue, scale) {

    context.beginPath();

    context.arc(coordinates[0], coordinates[1], 3 / scale, 0, Math.PI * 2);

    context.fillStyle = "hsla(" + hue + ", 100%, 50%, 0.8)";
    context.fill();

  },

  renderLineString: function(context, coordinates, hue, scale) {

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

  renderMultiLineString: function(context, coordinates, hue, scale) {

    var i;

    for (i = 0; i < coordinates.length; i++)
      this.renderLineString(context, coordinates[i], hue, scale);

  },

  renderPolygon: function(context, coordinates, hue, scale) {

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

  renderMultiPolygon: function(context, coordinates, hue, scale) {
    
    var i;

    for (i = 0; i < coordinates.length; i++)
      this.renderPolygon(context, coordinates[i], hue, scale);

  },

  renderTile: function(canvas, tile, inset) {
    
    if (typeof inset === "undefined")
      inset = 0;

    var context = canvas.getContext("2d");
    var scale = (canvas.width - inset * 2) / tile.scale;

    context.clearRect(0, 0, canvas.width, canvas.height);

    // Draw an outline around the tile

    context.lineWidth = 1;

    context.strokeStyle = "rgba(255, 255, 255, 0.5)";
    context.strokeRect(0.5, 0.5, canvas.width, canvas.height);

    // Set scale for features

    context.save();
    context.translate(inset, inset);
    context.scale(scale, scale);

    context.lineWidth = 2 / scale;

    // Iterate over features
    
    var i;

    for (i = 0; i < tile.features.length; i++) {
      
      var feature = tile.features[i];
      
      // Render feature
      
      var render;

      if (feature.geometry.type === "Point")
        render = this.renderPoint;
      else if (feature.geometry.type === "LineString")
        render = this.renderLineString;
      else if (feature.geometry.type === "MultiLineString")
        render = this.renderMultiLineString;
      else if (feature.geometry.type === "Polygon")
        render = this.renderPolygon;
      else if (feature.geometry.type === "MultiPolygon")
        render = this.renderMultiPolygon;

      if (typeof feature.id === "undefined")
        render.call(this, context, feature.geometry.coordinates, 45, scale);
      else
        render.call(this, context, feature.geometry.coordinates, feature.id, scale);

    }

    context.restore();

  }
  
}
