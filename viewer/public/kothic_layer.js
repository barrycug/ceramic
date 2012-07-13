var KothicLayer = L.TileLayer.Canvas.extend({
  
  options: {},
  
  initialize: function(url, options) {
    
    L.Util.setOptions(this, options);
    
    this._url = url;
    
    this._kothic = new Kothic({
      buffered: false,
      styles: MapCSS.availableStyles,
      locales: ['be', 'ru', 'en']
    });
    
  },
  
  drawTile: function(canvas, tilePoint, zoom) {
    
    var zoomOffset = this.options.zoomOffset;
  
    // load the tile
  
    var request = new XMLHttpRequest();
    var layer = this;
  
    request.onreadystatechange = function() {
      if (this.readyState == this.DONE) {
        if (this.status == 200 && this.responseText) {
          layer._renderTile(canvas, JSON.parse(this.responseText), zoom + zoomOffset);
        }
      }
    }
    
    var url = this._url.replace("{x}", tilePoint.x).
                        replace("{y}", tilePoint.y).
                        replace("{z}", zoom + zoomOffset);
  
    request.open("GET", url, true);
    request.send();
    
  },
  
  _renderTile: function(canvas, data, zoom) {
        
    data.granularity = data.scale;
    
    data.features = data.features.map(function(feature) {
      if (feature.type === "osm") {
        feature.type = feature.geometry.type;
        feature.coordinates = feature.geometry.coordinates;
        feature.properties = feature.tags;
      } else if (feature.type === "coastline") {
        feature.type = feature.geometry.type;
        feature.coordinates = feature.geometry.coordinates;
        feature.properties = {"natural":"coastline"};
      }
      return feature;
    });
    
    this._kothic.render(canvas, data, zoom, function(t) {});
    
  }
  
});
