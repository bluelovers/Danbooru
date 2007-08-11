class PostTagHistory < ActiveRecord::Base
	def author
		if user_id
			connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
		else
			CONFIG["default_guest_name"]
		end
	end

  def to_xml(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_xml(options.merge(:root => "tag_history"))
  end

	def to_json(options = {})
    {:id => id, :post_id => post_id, :tags => tags}.to_json(options)
	end
end
