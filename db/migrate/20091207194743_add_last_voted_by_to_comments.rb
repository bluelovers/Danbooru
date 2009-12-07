class AddLastVotedByToComments < ActiveRecord::Migration
  def self.up
    add_column :comments, :last_voted_by, :integer
    add_foreign_key :comments, :last_voted_by, :users, :id, :on_delete => :cascade
  end

  def self.down
    remove_column :comments, :last_voted_by
  end
end
