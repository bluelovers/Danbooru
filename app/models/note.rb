class Note < ActiveRecord::Base
	include ActiveRecord::Acts::Versioned

	belongs_to :post
	before_save :blank_body
	acts_as_versioned :table_name => "note_versions", :order => "updated_at DESC"
	after_save :update_post

	def self.active
		find(:all, :conditions => "is_active = TRUE")
	end

	def blank_body
		self.body = "(empty)" if self.body.blank?
	end

	def update_post
		activenotes = connection.select_value("SELECT 1 FROM notes WHERE is_active = TRUE AND post_id = #{self.post_id} LIMIT 1")
		if activenotes
			connection.execute(Note.sanitize_sql(["UPDATE posts SET last_noted_at = ? WHERE id = ?", Time.now, self.post_id]))
		else
			connection.execute(Note.sanitize_sql(["UPDATE posts SET last_noted_at = NULL WHERE id = ?", self.post_id]))
		end
	end

	def self.author(user_id)
		if user_id
			connection.select_value("SELECT name FROM users WHERE id = #{user_id}")
		else
			CONFIG["default_guest_name"]
		end
	end

	def author
		Note.author(self.user_id)
	end

	def locked?
		if "t" == connection.select_value("SELECT is_note_locked FROM posts WHERE id = #{post_id}")
			return true
		else
			return false
		end
	end
end
