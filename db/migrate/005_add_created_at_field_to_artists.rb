class AddCreatedAtFieldToArtists < ActiveRecord::Migration
  def self.up
    execute("ALTER TABLE artists ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT now()")
  end

  def self.down
    execute("ALTER TABLE artists DROP COLUMN created_at")
  end
end
