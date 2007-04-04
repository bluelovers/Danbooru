class TagImplication < ActiveRecord::Base
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
			Post.find(:all, :conditions => Tag.sanitize_sql(["id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = ?)", c.id])).each do |p|
				p.update_attributes(:tags => p.cached_tags + " " + parents, :updater_user_id => params[:updater_user_id], :updater_ip_addr => params[:updater_ip_addr])
			end
		end
	end
end
