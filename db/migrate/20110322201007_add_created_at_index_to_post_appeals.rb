class AddCreatedAtIndexToPostAppeals < ActiveRecord::Migration
  def self.up
    add_index :post_appeals, :created_at
  end

  def self.down
    remove_index :post_appeals, :created_at
  end
end
