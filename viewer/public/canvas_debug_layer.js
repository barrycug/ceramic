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
  
    request.onreadystatechange = function() {
      if (this.readyState == this.DONE) {
        if (this.status == 200 && this.responseText) {
          DebugRender.renderTile(canvas, JSON.parse(this.responseText));
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
