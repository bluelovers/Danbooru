class AddStatusToArtists < ActiveRecord::Migration
  def self.up
    add_column :artists, :is_active, :boolean, :null => false, :default => true
    add_column :artist_versions, :is_active, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :artists, :is_active
    remove_column :artist_versions, :is_active
  end
end
