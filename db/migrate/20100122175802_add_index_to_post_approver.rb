class AddIndexToPostApprover < ActiveRecord::Migration
  def self.up
    add_index :posts, :approver_id
  end

  def self.down
    remove_index :posts, :approver_id
  end
end
