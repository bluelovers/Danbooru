class FavoritesAddCreatedAt < ActiveRecord::Migration
  def self.up
    execute "alter table favorites add column created_at timestamp not null default '1960-01-01'"
  end

  def self.down
    execute "alter table favorites drop column created_at"
  end
end
