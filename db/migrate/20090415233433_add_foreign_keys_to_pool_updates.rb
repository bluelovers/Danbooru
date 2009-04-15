class AddForeignKeysToPoolUpdates < ActiveRecord::Migration
  def self.up
    add_foreign_key "pool_updates", "pool_id", "pools", "id", :on_delete => :cascade
  end

  def self.down
    remove_foreign_key "pool_updates", "pool_updates_pool_id_fkey"
  end
end
