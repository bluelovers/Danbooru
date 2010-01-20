class RemoveAliasIdGroupIdFromArtists < ActiveRecord::Migration
  def self.up
    remove_column :artists, :alias_id
    remove_column :artists, :group_id
    remove_column :artist_versions, :alias_id
    remove_column :artist_versions, :group_id
  end

  def self.down
    add_column :artists, :alias_id, :integer
    add_column :artists, :group_id, :integer
    add_column :artist_versions, :alias_id, :integer
    add_column :artist_versions, :group_id, :integer
  end
end
