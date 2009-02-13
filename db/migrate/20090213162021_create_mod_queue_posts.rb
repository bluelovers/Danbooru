class CreateModQueuePosts < ActiveRecord::Migration
  def self.up
    create_table :mod_queue_posts do |t|
      t.column :user_id, :integer, :null => false
      t.column :post_id, :integer, :null => false
    end
    
    add_foreign_key :mod_queue_posts, :user_id, :users, :id, :on_delete => :cascade
    add_foreign_key :mod_queue_posts, :post_id, :posts, :id, :on_delete => :cascade
  end

  def self.down
    drop_table :mod_queue_posts
  end
end
