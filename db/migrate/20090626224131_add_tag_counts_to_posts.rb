class AddTagCountsToPosts < ActiveRecord::Migration
  def self.up
    add_column "posts", "general_tag_count", :integer, :null => false, :default => 0
    add_column "posts", "artist_tag_count", :integer, :null => false, :default => 0
    add_column "posts", "character_tag_count", :integer, :null => false, :default => 0
    add_column "posts", "copyright_tag_count", :integer, :null => false, :default => 0
  end

  def self.down
    remove_column "posts", "general_tag_count"
    remove_column "posts", "artist_tag_count"
    remove_column "posts", "character_tag_count"
    remove_column "posts", "copyright_tag_count"
  end
end
