class AddCachedTagsToUsers < ActiveRecord::Migration
  def self.up
    rename_column "users", "my_tags", "recent_tags"
    add_column "users", "favorite_tags", :text, :null => false, :default => ""
    add_column "users", "enable_autocomplete", :boolean, :null => false, :default => true
  end

  def self.down
    rename_column "users", "recent_tags", "my_tags"
    remove_column "users", "favorite_tags"
    remove_column "users", "enable_autocomplete"
  end
end
