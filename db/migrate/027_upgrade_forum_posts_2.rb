class UpgradeForumPosts2 < ActiveRecord::Migration
	def self.up
		execute "ALTER TABLE forum_posts ADD COLUMN user_id INTEGER REFERENCES users ON DELETE SET NULL"
	end

	def self.down
		execute "ALTER TABLE forum_posts DROP COLUMN user_id"
	end
end
