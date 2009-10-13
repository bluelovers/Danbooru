class AddFileSizeIndexOnPosts < ActiveRecord::Migration
  def self.up
    add_index :posts, :file_size
  end

  def self.down
    remove_index :posts, :file_size
  end
end
