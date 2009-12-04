class AddCanModerateToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :can_moderate, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :users, :can_moderate
  end
end
