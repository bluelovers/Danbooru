class AddGroupNameToArtists < ActiveRecord::Migration
  def self.up
    add_column :artists, :group_name, :string
    add_column :artist_versions, :group_name, :string
  end

  def self.down
    remove_column :artists, :group_name
    remove_column :artist_versions, :group_name
  end
end
