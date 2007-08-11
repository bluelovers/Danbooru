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

  def formatted_body
    self.body.gsub(/<tn>(.+?)<\/tn>/, '<br/><p class="tn">\1</p>').gsub(/\n/, '<br/>')
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
		if connection.select_value("SELECT 1 FROM posts WHERE id = #{post_id} AND is_note_locked = TRUE")
			return true
		else
			return false
		end
	end

  def to_xml(options = {})
    {:created_at => created_at, :updated_at => updated_at, :creator_id => user_id, :x => x, :y => y, :width => width, :height => height, :is_active => is_active, :post_id => post_id, :body => body, :version => version}.to_xml(options.merge(:root => "note"))
  end

  def to_json(options = {})
    {:created_at => created_at, :updated_at => updated_at, :creator_id => user_id, :x => x, :y => y, :width => width, :height => height, :is_active => is_active, :post_id => post_id, :body => body, :version => version}.to_json(options)
  end
end
