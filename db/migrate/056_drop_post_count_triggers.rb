class DropPostCountTriggers < ActiveRecord::Migration
  def self.up
    execute "drop trigger trg_posts__insert on posts"
    execute "drop trigger trg_posts_delete on posts"
    execute "drop function trg_posts__insert()"
    execute "drop function trg_posts__delete()"
    execute "drop trigger trg_users_delete on users"
    execute "drop trigger trg_users_insert on users"
    execute "drop function trg_users__delete()"
    execute "drop function trg_users__insert()"
    execute "insert into table_data (name, row_count) values ('non-explicit_posts', (select count(*) from posts where rating <> 'e'))"
    execute "delete from table_data where name = 'safe_posts'"
  end

  def self.down
  end
end
