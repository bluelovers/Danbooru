class CreatePostAppeals < ActiveRecord::Migration
  def self.up
    create_table :post_appeals do |t|
      t.integer :post_id
      t.integer :user_id
      t.string :reason
      t.column :ip_addr, :inet

      t.timestamps
    end
    
    add_index :post_appeals, :post_id
    add_index :post_appeals, :user_id
    add_index :post_appeals, :ip_addr
  end

  def self.down
    drop_table :post_appeals
  end
end
