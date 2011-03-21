class ChangeUserRecordsIsPositiveToScore < ActiveRecord::Migration
  def self.up
    add_column :user_records, :score, :integer, :default => 0, :null => false
    execute "update user_records set score = -1 where is_positive = false"
    execute "update user_records set score = 1 where is_positive = true"
    remove_column :user_records, :is_positive
  end

  def self.down
    add_column :user_records, :is_positive, :boolean
    remove_column :user_records, :score
  end
end
