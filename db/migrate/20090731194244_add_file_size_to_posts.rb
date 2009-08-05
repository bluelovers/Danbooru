class AddFileSizeToPosts < ActiveRecord::Migration
  def self.up
    add_column :posts, :file_size, :integer
  end

  def self.down
    remove_column :posts, :file_size
  end
end
