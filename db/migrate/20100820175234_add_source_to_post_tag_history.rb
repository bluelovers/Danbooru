class AddSourceToPostTagHistory < ActiveRecord::Migration
  def self.up
    add_column :post_tag_histories, :source, :text
  end

  def self.down
    remove_column :post_tag_histories, :source
  end
end
