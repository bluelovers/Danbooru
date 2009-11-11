class AddParentIdToTagHistories < ActiveRecord::Migration
  def self.up
    add_column :post_tag_histories, :parent_id, :integer
  end

  def self.down
    remove_column :post_tag_histories, :parent_id
  end
end
