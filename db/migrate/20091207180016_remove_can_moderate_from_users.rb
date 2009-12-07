class RemoveCanModerateFromUsers < ActiveRecord::Migration
  def self.up
    remove_column :users, :can_moderate
  end

  def self.down
    add_column :users, :can_moderate, :boolean, :null => false, :default => true
  end
end
