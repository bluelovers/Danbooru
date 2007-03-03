class Comment < ActiveRecord::Base
	validates_format_of :body, :with => /\S/, :message => 'has no content'
	belongs_to :post
	belongs_to :user
	after_create :update_last_commented_at

	def mark_as_noise!
		connection.execute("UPDATE comments SET signal_level = 0 WHERE id = #{id}")
		if connection.select_value("SELECT COUNT(*) FROM comments WHERE post_id = #{post_id} AND signal_level <> 0").to_i == 0
			connection.execute("UPDATE posts SET last_commented_at = NULL WHERE id = #{post_id}")
		end
	end

	def mark_as_signal!
		connection.execute("UPDATE comments SET signal_level = 2 WHERE id = #{id}")
		connection.execute(Comment.sanitize_sql(["UPDATE posts SET last_commented_at = ? WHERE id = #{post_id}", Time.now]))
	end

	def update_last_commented_at
		connection.execute("UPDATE posts SET last_commented_at = '#{created_at.to_formatted_s(:db)}' WHERE id = #{post_id}")
	end

	def author
		if user
			user.name
		elsif @author
			@author
		elsif user_id
			@author = connection.select_value("SELECT name FROM users WHERE id = #{user_id}")
			@author
		else
			CONFIG["default_guest_name"]
		end
	end
end
