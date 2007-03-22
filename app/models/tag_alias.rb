class TagAlias < ActiveRecord::Base
	def self.create(params)
		id, n, a = nil, nil, nil

		transaction do
			n = Tag.find_or_create_by_name(params[:name])
			a = Tag.find_or_create_by_name(params[:alias])

			if find(:first, :conditions => ["name = ? AND alias_id = ?", n.name, a.id]) || find(:first, :conditions => ["name = ? AND alias_id = ?", a.name, n.id])
				raise "Tag alias already exists"
			end

			connection.execute(Tag.sanitize_sql(["DELETE FROM tag_aliases WHERE name = ? AND alias_id = ?", n.name, a.id]))

			connection.execute(Tag.sanitize_sql(["DELETE FROM posts_tags WHERE tag_id = ? AND post_id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = ?)", n.id, a.id]))
			connection.execute(Tag.sanitize_sql(["UPDATE posts_tags SET tag_id = ? WHERE tag_id = ?", a.id, n.id]))
			connection.execute(Tag.sanitize_sql(["UPDATE tags SET post_count = (SELECT COUNT(*) FROM posts_tags WHERE tag_id = tags.id) WHERE tags.name IN (?, ?)", n.name, a.name]))
		
			id = connection.insert(Tag.sanitize_sql(["INSERT INTO tag_aliases (name, alias_id) VALUES (?, ?)", n.name, a.id]))

			connection.select_values(Tag.sanitize_sql(["SELECT p.id FROM posts p, posts_tags pt WHERE (pt.tag_id = ? OR pt.tag_id = ?) AND pt.post_id = p.id", a.id, n.id])).each do |i|
				t = connection.select_values(Tag.sanitize_sql(["SELECT t.name FROM tags t, posts_tags pt WHERE pt.tag_id = t.id AND pt.post_id = ? ORDER BY t.name", i]))
				connection.execute(Tag.sanitize_sql(["UPDATE posts SET cached_tags = ? WHERE id = ?", t.join(" "), i]))
			end
		end

		return TagAlias.new(:id => id, :name => n.name, :alias_id => a.id)
	end
end
