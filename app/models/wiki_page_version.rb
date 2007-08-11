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

  def to_xml(options = {})
    {:id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version, :post_id => post_id}.to_xml(options.merge(:root => "wiki_page_version"))
  end

  def to_json(options = {})
    {:id => id, :created_at => created_at, :updated_at => updated_at, :title => title, :body => body, :updater_id => user_id, :locked => is_locked, :version => version, :post_id => post_id}.to_json(options)
  end
end
