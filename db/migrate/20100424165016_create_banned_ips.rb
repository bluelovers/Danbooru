class CreateBannedIps < ActiveRecord::Migration
  def self.up
    create_table :banned_ips do |t|
      t.column :creator_id, :integer, :null => false
      t.column :ip_addr, "inet", :null => false
      t.column :reason, :text
      t.timestamps
    end
    
    add_index :banned_ips, :ip_addr
  end

  def self.down
    drop_table :banned_ips
  end
end
