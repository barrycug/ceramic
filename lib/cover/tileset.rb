require "sqlite3"
require "digest/sha1"

module Cover
  
  class Tileset
  
    def initialize(database, options = {})
      
      @database = database
      
    end
    
    def create_schema
      
    @database.execute_batch <<-END
CREATE TABLE IF NOT EXISTS map (
  zoom_level INTEGER,
  tile_column INTEGER,
  tile_row INTEGER,
  tile_id TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS map_index ON map (zoom_level, tile_column, tile_row);

CREATE TABLE IF NOT EXISTS objects (
  tile_data BLOB,
  tile_id TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS objects_id ON objects (tile_id);

CREATE VIEW IF NOT EXISTS tiles AS
  SELECT
    map.zoom_level AS zoom_level,
    map.tile_column AS tile_column,
    map.tile_row AS tile_row,
    objects.tile_data AS tile_data
  FROM
    map
    JOIN objects ON objects.tile_id = map.tile_id;
    
CREATE TABLE IF NOT EXISTS metadata (
  name text,
  value text
);
CREATE UNIQUE INDEX IF NOT EXISTS name ON metadata (name);
END

    end
  
    def set_metadata(metadata)
      
      @database.transaction do |db|
        
        db.execute("DELETE FROM metadata")
        
        metadata.each do |name, value|
          db.execute <<-END, { "name" => name.to_s, "value" => value.to_s }
INSERT INTO metadata (name, value) VALUES (:name, :value)
END
        end
        
      end
      
    end
  
    def get_metadata
      
      metadata = {}
      
      @database.execute("SELECT name, value FROM metadata") do |row|
        metadata[row[0]] = row[1]
      end
      
      metadata
      
    end
  
    def insert_tile(index, data)
      
      id = Digest::SHA1.hexdigest(data)
    
      @database.execute <<-END, { "data" => data, "id" => id }
INSERT OR REPLACE INTO objects (tile_data, tile_id) VALUES (:data, :id);
END
    
      @database.execute <<-END, { "z" => index.z, "x" => index.x, "y" => index.y, "id" => id }
INSERT OR REPLACE INTO map (zoom_level, tile_column, tile_row, tile_id) VALUES (:z, :x, :y, :id);
END
    
    end
  
    def select_tile(index)
      
      @database.get_first_value <<-END, { "z" => index.z, "x" => index.x, "y" => index.y }
SELECT tile_data FROM tiles WHERE zoom_level = :z AND tile_column = :x AND tile_row = :y
END

    end
  
    def optimize
      
      @database.execute("ANALYZE")
      @database.execute("VACUUM")
      
    end
    
  end
  
end
