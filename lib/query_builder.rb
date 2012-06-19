class QueryBuilder
  
  def initialize(config, connection)
    @config = config
    @connection = connection
  end
  
  # Output an array of query argument arrays for the given tile index (and configuration)
  
  def queries(index)
    
    result = []
    
    @config["tables"].each do |table|
      
      case table["geometry"]
      when "point"
        result << point_query_arguments(index, :columns => table["columns"], :table => table["name"])
      when "line"
        result << line_query_arguments(index, :columns => table["columns"], :table => table["name"])
      when "polygon"
        result << polygon_query_arguments(index, :columns => table["columns"], :table => table["name"])
      end
      
    end
    
    result
    
  end
  
  protected
  
    # "Prepare" a query for finding points within the tile (arguments
    # will be given to the PG::Connection#exec method).
  
    def point_query_arguments(index, options = {})
      return [<<-END, [-index.left, -index.top, @config["granularity"].to_f / index.width, @config["granularity"].to_f / index.height, index.bbox[0], index.bbox[1], index.bbox[2], index.bbox[3]]]
select
  ST_AsGeoJSON(ST_TransScale(way, $1, $2, $3, $4), 0) as geometry
  #{(options[:columns] ? "," : "") + options[:columns].map { |c| @connection.quote_ident(c) }.join(", ")}
from
  #{@connection.quote_ident(options[:table])}
where
  way && ST_MakeEnvelope($5, $6, $7, $8, 3857)
END
    end
    
    def line_query_arguments(index, options = {})
      return [<<-END, [index.bbox[0], index.bbox[1], index.bbox[2], index.bbox[3], -index.left, -index.top, @config["granularity"].to_f / index.width, @config["granularity"].to_f / index.height]]
select
  ST_AsGeoJSON(
    ST_TransScale(
      ST_Intersection(
        way,
        ST_MakeEnvelope($1, $2, $3, $4, 900913)
      ),
      $5, $6, $7, $8
    ),
    0
  ) as geometry
  #{(options[:columns] ? "," : "") + options[:columns].map { |c| @connection.quote_ident(c) }.join(", ")}
from
  #{@connection.quote_ident(options[:table])}
where
  way && ST_MakeEnvelope($1, $2, $3, $4, 900913)
END
    end
    
    def polygon_query_arguments(index, options = {})
      return [<<-END, [index.bbox[0], index.bbox[1], index.bbox[2], index.bbox[3], -index.left, -index.top, @config["granularity"].to_f / index.width, @config["granularity"].to_f / index.height]]
select
  ST_AsGeoJSON(
    ST_TransScale(
      ST_ForceRHR(
        ST_Intersection(
          ST_Buffer(way, 0.0),
          ST_MakeEnvelope($1, $2, $3, $4, 900913)
        )
      ),
      $5, $6, $7, $8
    ),
    0
  ) as geometry
  #{(options[:columns] ? "," : "") + options[:columns].map { |c| @connection.quote_ident(c) }.join(", ")}
from
  #{@connection.quote_ident(options[:table])}
where
  way && ST_MakeEnvelope($1, $2, $3, $4, 900913)
END
    end
  
end
