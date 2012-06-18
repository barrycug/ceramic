class Tile
  
  attr_reader :z, :x, :y
  
  def self.from_index(index)
    parts = index.split("/").map { |p| p.to_i }
    
    if parts.size != 3
      raise ArgumentError.new("index must look like z/x/y")
    end
    
    self.new(*parts)
  end
  
  def initialize(z, x, y)
    @z, @x, @y = z, x, y
  end
  
  def bbox
    @bbox ||= convert_4326_to_3857(tile_to_lon(@x, @z), tile_to_lat(@y+1, @z)) +
              convert_4326_to_3857(tile_to_lon(@x+1, @z), tile_to_lat(@y, @z))
  end
  
  def left
    @left ||= bbox[0]
  end
  
  def right
    @right ||= bbox[2]
  end
  
  def top
    @top ||= bbox[3]
  end
  
  def bottom
    @bottom ||= bbox[1]
  end
  
  def width
    @width ||= right - left
  end
  
  def height
    @height ||= bottom - top
  end
  
  protected
  
    # From Tiny WMS
    # http://code.google.com/p/twms/source/browse/twms/projections.py
  
    def convert_4326_to_3857(lon, lat)
      lat_rad = lat * (Math::PI / 180.0)
      x = lon * 111319.49079327358
      y = Math.log(Math.tan(lat_rad) + (1 / Math.cos(lat_rad))) / Math::PI * 20037508.342789244
      [x, y]
    end
    
    # From the OSM wiki
  
    def tile_to_lon(x, z)
      x.to_f / (2 ** z.to_f) * 360.0 - 180.0
    end

    def tile_to_lat(y, z)
      n = Math::PI - (2.0 * Math::PI * y.to_f) / (2.0 ** z.to_f)
      180.0 / Math::PI * Math.atan(Math.sinh(n))
    end
  
end
