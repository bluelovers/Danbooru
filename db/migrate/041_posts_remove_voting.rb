class PostsRemoveVoting < ActiveRecord::Migration
  def self.up
    remove_column :posts, :last_voter_ip
    execute "update posts set score = (select count(*) from favorites where post_id = posts.id)"
  end

  def self.down
    add_column :posts, :last_voter_ip, :text
  end
end
