function renderPoint(context, coordinates, hue, scale) {
  
  context.beginPath();
  
  context.arc(coordinates[0], coordinates[1], 3 / scale, 0, Math.PI * 2);
      
  context.fillStyle = "hsla(" + hue + ", 100%, 50%, 0.8)";
  context.fill();
  
}

function renderLineString(context, coordinates, hue, scale) {
  
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
  
}

function renderMultiLineString(context, coordinates, hue, scale) {
  
  var i;
  
  for (i = 0; i < coordinates.length; i++)
    renderLineString(context, coordinates[i], hue, scale);
  
}

function renderPolygon(context, coordinates, hue, scale) {
  
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
  
}

function renderMultiPolygon(context, coordinates, hue, scale) {
  
  var i;
  
  for (i = 0; i < coordinates.length; i++)
    renderPolygon(context, coordinates[i], hue, scale);
  
}

function renderTile(canvas, data) {
  
  var context = canvas.getContext("2d");
  var scale = canvas.width / data.granularity;
  
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
  
  data.features.forEach(function(feature) {
    
    // Render feature
    
    var render;
    
    if (feature.geometry.type === "Point")
      render = renderPoint;
    else if (feature.geometry.type === "LineString")
      render = renderLineString;
    else if (feature.geometry.type === "MultiLineString")
      render = renderMultiLineString;
    else if (feature.geometry.type === "Polygon")
      render = renderPolygon;
    else if (feature.geometry.type === "MultiPolygon")
      render = renderMultiPolygon;
    
    if (typeof feature.properties.osm_id === "undefined")
      render(context, feature.geometry.coordinates, 45, scale);
    else
      render(context, feature.geometry.coordinates, feature.properties.osm_id, scale);
    
  });
  
  context.restore();
  
}
