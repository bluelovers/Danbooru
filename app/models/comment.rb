class Comment < ActiveRecord::Base
	validates_format_of :body, :with => /\S/, :message => 'has no content'
	belongs_to :post
	belongs_to :user
	after_create :update_last_commented_at

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
