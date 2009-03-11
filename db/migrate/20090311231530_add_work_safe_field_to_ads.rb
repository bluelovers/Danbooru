class AddWorkSafeFieldToAds < ActiveRecord::Migration
  def self.up
    add_column "advertisements", "is_work_safe", :boolean, :default => false, :null => false
  end

  def self.down
    remove_column "advertisements", "is_work_safe"
  end
end
