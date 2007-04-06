class TagAlias < ActiveRecord::Base
	after_destroy :update_cached_tags

	def alias=(name)
		tag = Tag.find_or_create_by_name(name)
		self.alias_id = tag.id
	end

	def update_cached_tags
		Tag.update_cached_tags([self.name, Tag.find(self.alias_id).name])
	end

	def approve!
		id, n, a = nil, nil, nil

		transaction do
			n = Tag.find_or_create_by_name(self.name)
			a = Tag.find(self.alias_id)

			if self.class.find(:first, :conditions => ["(name = ? AND alias_id = ?) OR (name = ? AND alias_id = ?)", n.name, a.id, a.name, n.id])
				raise "Tag alias already exists"
			end

			connection.execute(Tag.sanitize_sql(["DELETE FROM posts_tags WHERE tag_id = ? AND post_id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = ?)", n.id, a.id]))
			connection.execute(Tag.sanitize_sql(["UPDATE posts_tags SET tag_id = ? WHERE tag_id = ?", a.id, n.id]))
			connection.execute(Tag.sanitize_sql(["UPDATE tags SET post_count = (SELECT COUNT(*) FROM posts_tags WHERE tag_id = tags.id) WHERE tags.name IN (?, ?)", n.name, a.name]))

			Tag.update_cached_tags([a.name, p.name])
		end
	end
end
