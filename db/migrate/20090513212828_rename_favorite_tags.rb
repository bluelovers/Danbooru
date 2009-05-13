class RenameFavoriteTags < ActiveRecord::Migration
  def self.up
    rename_column :users, :favorite_tags, :uploaded_tags
  end

  def self.down
    rename_column :users, :uploaded_tags, :favorite_tags
  end
end
