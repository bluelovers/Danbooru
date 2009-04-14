class AddBaseUploadLimitToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :base_upload_limit, :integer
  end

  def self.down
    remove_column :users, :base_upload_limit
  end
end
