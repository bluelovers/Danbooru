class CreateMiscIndexes < ActiveRecord::Migration
  def self.up
    add_index :comments, :user_id
    add_index :wiki_page_versions, :user_id
    add_index :forum_posts, :creator_id
    add_index :pool_updates, :user_id
  end

  def self.down
    remove_index :comments, :user_id
    remove_index :wiki_page_versions, :user_id
    remove_index :forum_posts, :creator_id
    remove_index :pool_updates, :user_id
  end
end
