class TagAlias < ActiveRecord::Base
	def alias=(name)
		tag = Tag.find_or_create_by_name(name)
		self.alias_id = tag.id
	end

	def approve!
		n = Tag.find_or_create_by_name(self.name)
		a = Tag.find(self.alias_id)

		transaction do
			if self.class.find(:first, :conditions => ["is_pending = FALSE AND (name = ? OR name = ?)", n.name, a.name])
				raise "Tag alias already exists"
			end

			connection.execute(Tag.sanitize_sql(["DELETE FROM posts_tags WHERE tag_id = ? AND post_id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = ?)", n.id, a.id]))
			connection.execute(Tag.sanitize_sql(["UPDATE posts_tags SET tag_id = ? WHERE tag_id = ?", a.id, n.id]))
			connection.execute(Tag.sanitize_sql(["UPDATE tags SET post_count = (SELECT COUNT(*) FROM posts_tags WHERE tag_id = tags.id) WHERE tags.name IN (?, ?)", n.name, a.name]))
			connection.execute("UPDATE tag_aliases SET is_pending = FALSE WHERE id = #{self.id}")
		end

		Tag.update_cached_tags([a.name, n.name])
	end

# Maps tag synonyms to their preferred names. Returns an array of strings.
	def self.to_aliased(tags)
		return [] if tags.blank?
		aliased = []

		[*tags].each do |t|
			aliased << connection.select_value(sanitize_sql([<<-SQL, t, t]))
				SELECT coalesce(
					(
						SELECT t.name 
						FROM tags t, tag_aliases ta 
						WHERE ta.name = ? 
						AND ta.alias_id = t.id
						AND ta.is_pending = FALSE
					), 
					?
				)
			SQL
		end

		if tags.is_a?(String)
			return aliased[0]
		else
			return aliased
		end
	end

  def to_xml(options = {})
    {:id => id, :name => name, :alias_id => alias_id, :pending => is_pending}.to_xml("alias", options)
  end

  def to_json(options = {})
    {:id => id, :name => name, :alias_id => alias_id, :pending => is_pending}.to_json(options)
  end
end
