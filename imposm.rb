class Imposm
  
  def setup
    @connection = PG.connect(dbname: "imposm")
  end
  
  def teardown
    @connection.close
  end
  
  def maker
    
    # Basic default Imposm tables
    
    tables = [
      { :name => "places", :type => :point },
      { :name => "admin", :type => :polygon },
      { :name => "motorways", :type => :line },
      { :name => "mainroads", :type => :line },
      { :name => "buildings", :type => :polygon },
      { :name => "minorroads", :type => :line },
      { :name => "transport_points", :type => :point },
      { :name => "railways", :type => :line },
      { :name => "waterways", :type => :line },
      { :name => "waterareas", :type => :polygon },
      { :name => "aeroways", :type => :line },
      { :name => "transport_areas", :type => :polygon },
      { :name => "landusages", :type => :polygon },
      { :name => "amenities", :type => :point }
    ]
    
    sources = tables.map do |table|
      Cover::Source.new(
        "osm_new_#{table[:name]}",
        connection: @connection,
        srid: 900913,
        geometry: {
          "geometry" => { type: table[:type] }
        },
        bbox: "geometry"
      )
    end
    
    # Builder
    
    builder = Cover::Builder.new do |row|
      if row["geometry"]["type"] == "GeometryCollection"
        nil
      else
        row.inject({}) do |hash, (name, value)|
          hash[name] = value unless value.nil?
          hash
        end
      end
    end
    
    # Maker
    
    Cover::Maker.new(scale: 8192) do |index, features|
      
      sources.each do |source|
        features.make(source, builder)
      end
      
    end
    
  end

end

Cover.config = Imposm.new
