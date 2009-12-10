class CreateCommentVotes < ActiveRecord::Migration
  def self.up
    remove_column "comments", "last_voted_by"
    
    create_table "comment_votes" do |t|
      t.column "comment_id", :integer, :null => false
      t.column "user_id", :integer, :null => false
      t.timestamps
    end

    add_index "comment_votes", "created_at"
    add_index "comment_votes", "comment_id"
    add_index "comment_votes", "user_id"
    add_foreign_key "comment_votes", "comment_id", "comments", "id", :on_delete => :cascade
    add_foreign_key "comment_votes", "user_id", "users", "id", :on_delete => :cascade
    
    add_index "post_votes", "created_at"
  end

  def self.down
    drop_table "comment_votes"
    add_column "comments", "last_voted_by", :integer, :default => "1"
    add_foreign_key "comments", "last_voted_by", "users", "id", :on_delete => :cascade
    
    remove_index "post_votes", "created_at"
  end
end
