class AddIsBannedToArtists < ActiveRecord::Migration
  def self.up
    add_column :artists, :is_banned, :boolean, :null => false, :default => false
    add_column :artist_versions, :is_banned, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :artists, :is_banned
    remove_column :artist_versions, :is_banned
  end
end
