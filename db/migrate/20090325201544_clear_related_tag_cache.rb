class ClearRelatedTagCache < ActiveRecord::Migration
  def self.up
    execute "UPDATE tags SET cached_related = ''"
  end

  def self.down
  end
end
