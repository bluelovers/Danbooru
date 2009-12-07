class CreateTestJanitors < ActiveRecord::Migration
  def self.up
    create_table :test_janitors do |t|
      t.column :user_id, :integer, :null => false
      t.column :test_promotion_date, :datetime, :null => false
      t.column :promotion_date, :datetime
      t.column :original_level, :integer, :null => false
      t.timestamps
    end
    
    add_foreign_key :test_janitors, :user_id, :users, :id, :on_delete => :cascade
    add_index :test_janitors, :user_id
  end

  def self.down
    drop_table :test_janitors
  end
end
