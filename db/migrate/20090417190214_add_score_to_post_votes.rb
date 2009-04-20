class AddScoreToPostVotes < ActiveRecord::Migration
  def self.up
    add_column :post_votes, :score, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :post_votes, :score
  end
end
