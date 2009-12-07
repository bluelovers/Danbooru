class AddScoreToComments < ActiveRecord::Migration
  def self.up
    add_column :comments, :score, :integer, :null => false, :default => 0
    execute "update comments set score = -1 where is_spam = true"
    remove_column :comments, :is_spam
  end

  def self.down
    add_column :comments, :is_spam, :boolean
    remove_column :comments, :score
  end
end
