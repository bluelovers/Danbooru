class WikiPageVersion < ActiveRecord::Base
	def author
		if self.user_id
			connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
		else
			CONFIG['default_guest_name']
		end
	end

	def pretty_title
		self.title.tr("_", " ")
	end
end
