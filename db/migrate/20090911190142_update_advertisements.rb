class UpdateAdvertisements < ActiveRecord::Migration
  def self.up
    add_column :advertisements, :file_name, :string
    add_column :advertisements, :created_at, :datetime
    
    execute "update advertisements set created_at = '2009-06-22' where image_url like '%20090622%'"
    execute "update advertisements set created_at = '2009-04-19' where image_url like '%20090419%'"
    execute "update advertisements set created_at = '2009-05-25' where image_url like '%20090525%'"
    execute "update advertisements set created_at = '2009-06-22' where image_url like '%20090622%'"
    execute "update advertisements set file_name = substring(image_url, 22, 100)"
    
    remove_column :advertisements, :image_url
  end

  def self.down
    add_column :advertisements, :image_url, :string
    
    remove_column :advertisements, :file_name
    remove_column :advertisements, :created_at
  end
end
