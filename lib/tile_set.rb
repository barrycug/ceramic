require "sqlite3"
require "digest/sha1"

class TileSet
  
  def initialize(file_name)
    @database = SQLite3::Database.new(file_name)
    
    # http://www.sqlite.org/pragma.html#pragma_synchronous
    # http://www.sqlite.org/pragma.html#pragma_locking_mode
    @database.execute("PRAGMA synchronous=0")
    @database.execute("PRAGMA locking_mode=EXCLUSIVE")
  end
  
  def finalize
    @database.execute("ANALYZE;")
    @database.execute("VACUUM;")
  end
  
  def close
    unless @database.closed?
      @database.close
    end
  end
  
  def add_tile(index, data)
    
    id = Digest::SHA1.hexdigest(data)
    
    @database.execute <<-END, { "data" => data, "id" => id }
INSERT OR IGNORE INTO objects (tile_data, tile_id) VALUES (:data, :id);
END
    
    @database.execute <<-END, { "z" => index.z, "x" => index.x, "y" => index.y, "id" => id }
INSERT INTO map (zoom_level, tile_column, tile_row, tile_id) VALUES (:z, :x, :y, :id);
END
    
  end
  
  def create_schema
    @database.execute_batch <<-END
CREATE TABLE map (
  zoom_level INTEGER,
  tile_column INTEGER,
  tile_row INTEGER,
  tile_id TEXT
);
CREATE UNIQUE INDEX map_index ON map (zoom_level, tile_column, tile_row);

CREATE TABLE objects (
  tile_data BLOB,
  tile_id TEXT
);
CREATE UNIQUE INDEX objects_id ON objects (tile_id);

CREATE VIEW tiles AS
  SELECT
    map.zoom_level AS zoom_level,
    map.tile_column AS tile_column,
    map.tile_row AS tile_row,
    objects.tile_data AS tile_data
  FROM
    map
    JOIN objects ON objects.tile_id = map.tile_id;
    
CREATE TABLE metadata (
  name text,
  value text
);
CREATE UNIQUE INDEX name ON metadata (name);
END
  end
  
  def insert_metadata
    @database.execute <<-END, { "name" => "format", "value" => "js" }
INSERT INTO metadata (name, value) VALUES (:name, :value);
END
  end
  
end
