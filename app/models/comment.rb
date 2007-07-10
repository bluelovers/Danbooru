class Comment < ActiveRecord::Base
	validates_format_of :body, :with => /\S/, :message => 'has no content'
	belongs_to :post
	belongs_to :user
	after_save :update_last_commented_at

	def update_last_commented_at
    has_comments = connection.select_value("SELECT 1 FROM comments WHERE post_id = #{self.post_id} AND is_spam <> TRUE LIMIT 1").to_i
    if has_comments
      connection.execute("UPDATE posts SET last_commented_at = '#{created_at.to_formatted_s(:db)}' WHERE id = #{post_id}")
    else
      connection.execute("UPDATE posts SET last_commented_at = NULL WHERE id = #{post_id}")
    end
	end

	def author
		if user_id
			connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
		else
			CONFIG["default_guest_name"]
		end
	end

  def to_xml(options = {})
    {:id => id, :created_at => created_at, :post_id => post_id, :creator_id => user_id, :body => body}.to_xml("comment", options)
  end

  def to_json(options = {})
    {:id => id, :created_at => created_at, :post_id => post_id, :creator_id => user_id, :body => body}.to_json(options)
  end
end
