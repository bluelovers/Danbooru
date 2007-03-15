class PostTagHistory < ActiveRecord::Base
	def author
		if user_id
			connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
		else
			CONFIG["default_guest_name"]
		end
	end
end
