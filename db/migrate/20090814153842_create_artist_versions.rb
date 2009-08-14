class CreateArtistVersions < ActiveRecord::Migration
  def self.up
    create_table :artist_versions do |t|
      t.column :artist_id, :integer
      t.column :version, :integer, :null => false, :default => 0
      t.column :alias_id, :integer
      t.column :group_id, :integer
      t.column :name, :text
      t.column :updater_id, :integer
      t.column :cached_urls, :text
      t.timestamps
    end
    
    add_index :artist_versions, :artist_id
    add_index :artist_versions, :updater_id
    
    add_column :artists, :version, :integer
  end

  def self.down
    drop_table :artist_versions
    remove_column :artists, :version
  end
end
