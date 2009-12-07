class AddCommentThresholdToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :comment_threshold, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :users, :comment_threshold
  end
end
