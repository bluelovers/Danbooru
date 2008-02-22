class AddApprovedByToPosts < ActiveRecord::Migration
  def self.up
    add_column :posts, :approved_by, :integer
    add_foreign_key :posts, :approved_by, :users, :id
  end

  def self.down
    drop_column :posts, :approved_by
  end
end
