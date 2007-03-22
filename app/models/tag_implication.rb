class TagImplication < ActiveRecord::Base
	attr_accessor :updater_user_id
	attr_accessor :updater_ip_addr

	def self.create(params)
		transaction do
			p = Tag.find_or_create_by_name(params[:parent])
			c = Tag.find_or_create_by_name(params[:child])

			if find(:first, :conditions => ["parent_id = ? AND child_id = ?", p.id, c.id]) || find(:first, :conditions => ["parent_id = ? AND child_id = ?", c.id, p.id])
				raise "Tag implication already exists"
			end

			unless connection.select_value(Tag.sanitize_sql(["SELECT 1 FROM tag_implications WHERE parent_id = ? AND child_id = ?", p.id, c.id]))
				connection.execute(Tag.sanitize_sql(["INSERT INTO tag_implications (parent_id, child_id) VALUES (?, ?)", p.id, c.id]))
			end

			parents = Tag.with_parents(c.name).join(" ")
			Post.find(:all, :joins => Tag.sanitize_sql(["JOIN posts_tags pt ON pt.post_id = posts.id WHERE pt.tag_id = ?", c.id])).each do |p|
				p.update_attributes(:tags => p.cached_tags + " " + parents, :updater_user_id => self.updater_user_id, :updater_ip_addr => self.updater_ip_addr)
			end
		end
	end
end
