class AddCreatedAtIndexToModActions < ActiveRecord::Migration
  def self.up
    add_index :mod_actions, :created_at
  end

  def self.down
    remove_index :mod_actions, :created_at
  end
end
