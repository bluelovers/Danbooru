class RenameUsersBaseUploadLimit < ActiveRecord::Migration
  def self.up
    rename_column :users, :base_upload_limit, :upload_limit
    execute "UPDATE users SET upload_limit = 10 WHERE upload_limit < 0"
    execute "UPDATE users SET upload_limit = NULL WHERE upload_limit <= 10"
  end

  def self.down
    rename_column :users, :upload_limit, :base_upload_limit
  end
end
