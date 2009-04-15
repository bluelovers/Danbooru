class CreatePostVotes < ActiveRecord::Migration
  def self.up
    remove_column "posts", "last_voter_ip"
    
    create_table "post_votes" do |t|
      t.column "post_id", :integer, :null => false
      t.column "user_id", :integer, :null => false
      t.timestamps
    end
    
    add_index "post_votes", "post_id"
    add_index "post_votes", "user_id"
    add_foreign_key "post_votes", "post_id", "posts", "id", :on_delete => :cascade
    add_foreign_key "post_votes", "user_id", "users", "id", :on_delete => :cascade
  end

  def self.down
    drop_table "post_votes"
    add_column "posts", "last_voter_ip", "inet", :default => "127.0.0.1"
  end
end
