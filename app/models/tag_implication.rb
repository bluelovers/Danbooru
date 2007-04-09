class TagImplication < ActiveRecord::Base
	def predicate
		return Tag.find(self.predicate_id)
	end

	def consequent
		return Tag.find(self.consequent_id)
	end

	def predicate=(name)
		t = Tag.find_or_create_by_name(name)
		self.predicate_id = t.id
	end

	def consequent=(name)
		t = Tag.find_or_create_by_name(name)
		self.consequent_id = t.id
	end

	def approve!(user_id, ip_addr)
		transaction do
			p = Tag.find(self.predicate_id)
			c = Tag.find(self.consequent_id)

			if self.class.find(:first, :conditions => ["is_pending = FALSE AND ((predicate_id = ? AND consequent_id = ?) OR (predicate_id = ? AND consequent_id = ?))", p.id, c.id, c.id, p.id])
				raise "Tag implication already exists"
			end

			implied_tags = self.class.with_implied(p.name).join(" ")
			Post.find(:all, :conditions => Tag.sanitize_sql(["id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = ?)", p.id])).each do |tag|
				tag.update_attributes(:tags => tag.cached_tags + " " + implied_tags, :updater_user_id => user_id, :updater_ip_addr => ip_addr)
			end

			connection.execute("UPDATE tag_implications SET is_pending = FALSE WHERE id = #{self.id}")
		end
	end

	def self.with_implied(tags)
		return [] if tags.blank?
		all = []

		tags.each do |tag|
			all << tag
			results = [tag]

			10.times do
				results = connection.select_values(sanitize_sql([<<-SQL, results]))
					SELECT t1.name 
					FROM tags t1, tags t2, tag_implications ti 
					WHERE ti.predicate_id = t2.id 
					AND ti.consequent_id = t1.id 
					AND t2.name IN (?)
					AND ti.is_pending = FALSE
				SQL

				if results.any?
					all += results
				else
					break
				end
			end
		end

		return all
	end
end
