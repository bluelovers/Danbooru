class CreatePoolUpdates < ActiveRecord::Migration
  def self.up
    create_table "pool_updates" do |t|
      t.column "pool_id", :integer, :null => false
      t.column "post_ids", :text, :null => false, :default => ""
      t.column "user_id", :integer
      t.column "ip_addr", "inet"
      t.timestamps
    end
    
    add_index "pool_updates", "pool_id"
  end

  def self.down
    drop_table "pool_updates"
  end
end
