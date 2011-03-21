class CreateModActions < ActiveRecord::Migration
  def self.up
    create_table :mod_actions do |t|
      t.column :user_id, :integer
      t.column :description, :text
      t.timestamps
    end
    
    add_index :mod_actions, :user_id
  end

  def self.down
    remove_table :mod_actions
  end
end
