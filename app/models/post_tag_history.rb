class PostTagHistory < ActiveRecord::Base
	def author
		if user_id
			connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
		else
			CONFIG["default_guest_name"]
		end
	end

	def to_json(options = {})
		"{id:%s, post_id:%s, tags:'%s'}" % [self.id, self.post_id, self.tags.gsub(/\\/, '\0\0').gsub(/["']/) {|m| "\\#{m}"}]
	end
end
