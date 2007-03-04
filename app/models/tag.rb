class Tag < ActiveRecord::Base
	serialize :cached_related
	after_create :related

	TYPE_GENERAL	= 0
	TYPE_ARTIST 	= 1
	TYPE_AMBIGUOUS	= 2
	TYPE_COPYRIGHT	= 3
	TYPE_CHARACTER	= 4

	def before_create
		if self.cached_related_expires_on.nil?
			self.cached_related_expires_on = Time.now
		end
	end

	def self.type(name)
		return connection.select_value(sanitize_sql(["SELECT tag_type FROM tags WHERE name = ?", name])).to_i
	end

	def self.find_or_create_by_name(name)
		tag_type = TYPE_GENERAL

		if name =~ /^artist:/
			name.gsub!(/^artist:/, '')
			tag_type = TYPE_ARTIST
		elsif name =~ /^(copyright|copy):/
			name.gsub!(/^(copyright|copy):/, '')
			tag_type = TYPE_COPYRIGHT
		elsif name =~ /^(character|char|ch):/
			name.gsub!(/^(character|char|ch):/, '')
			tag_type = TYPE_CHARACTER
		end

		t = Tag.find_by_name(name)
		if t
			if t.tag_type == TYPE_GENERAL && t.tag_type != tag_type
				connection.execute("UPDATE tags SET tag_type = #{tag_type} WHERE id = #{t.id}")
			end
			return t
		end

		connection.execute(Tag.sanitize_sql(["INSERT INTO tags (name, tag_type) VALUES (?, ?)", name, tag_type]))

		return Tag.find_by_name(name)
	end

	def calculate_related
		return connection.select_all(Tag.sanitize_sql([<<-SQL, self.name])).map {|i| [i["tag"], i["tag_count"]]}
			SELECT (
				SELECT name 
				FROM tags 
				WHERE id = pt1.tag_id
			) AS tag, 
			COUNT(pt1.tag_id) AS tag_count 
			FROM posts_tags pt1, posts_tags pt2, tags t
			WHERE pt1.post_id = pt2.post_id
			AND pt2.tag_id = t.id
			AND t.name = ?
			GROUP BY pt1.tag_id 
            ORDER BY tag_count DESC
            LIMIT 25
		SQL
	end

	def self.find_related(name)
		t = Tag.find_by_name(name)
		if t
			t.related
		else
			[]
		end
	end

	def self.select_ambiguous(tags)
		tags = Tag.scan_tags(tags)
		return connection.select_values(Tag.sanitize_sql(["SELECT name FROM tags WHERE name IN (?) AND tag_type = 2 ORDER BY name", tags]))
	end

	def self.update_cached_tags(tags)
		post_ids = connection.select_values(Tag.sanitize_sql(["SELECT pt.post_id FROM posts_tags pt, tags t WHERE pt.tag_id = t.id AND t.name IN (?)", tags]))
		connection.execute("BEGIN TRANSACTION")
		post_ids.each do |i|
			tags = connection.select_values("SELECT t.name FROM tags t, posts_tags pt WHERE t.id = pt.tag_id ORDER BY t.name").join(" ")
			connection.execute(Tag.sanitize_sql(["UPDATE posts SET cached_tags = ? WHERE id = ?", tags, i]))
		end
		connection.execute("COMMIT")
	end
	
	def related
		if Time.now > self.cached_related_expires_on
			length = (self.post_count / 20).to_i
			length = 8 if length < 8
			connection.execute(Tag.sanitize_sql(["UPDATE tags SET cached_related = ?, cached_related_expires_on = ? WHERE id = #{id}", self.calculate_related.to_yaml, length.hours.from_now]))
			self.reload
		end

		return cached_related
	end

	def to_s
		name
	end

	def <=>(rhs)
		name <=> rhs.name
	end

	def self.scan_query(query)
		query.to_s.downcase.scan(/\S+/).uniq
	end

	def self.scan_tags(tags)
		tags.to_s.gsub(/[*%,]/, "").downcase.scan(/\S+/).uniq
	end

# Maps tag synonyms to their preferred names. Returns an array of strings.
	def self.to_aliased(tags)
		aliased = []

		[*tags].each do |t|
			aliased << connection.select_value(sanitize_sql([<<-SQL, t, t]))
				SELECT coalesce(
					(
						SELECT t.name 
						FROM tags t, tag_aliases ta 
						WHERE ta.name = ? 
						AND ta.alias_id = t.id
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

	def self.with_parents(tags)
		all = []

		tags.each do |tag|
			all << tag
			results = [tag]

			10.times do
				results = connection.select_values(sanitize_sql([<<-SQL, results]))
					SELECT t1.name 
					FROM tags t1, tags t2, tag_implications ti 
					WHERE ti.child_id = t2.id 
					AND ti.parent_id = t1.id 
					AND t2.name IN (?)
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

# Parses a query into three sets of tags: reject, union, and intersect.
#
# === Parameters
# * +query+: String, array, or nil. The query to parse.
# * +options+: A hash of options.
	def self.parse_query(query, options = {})
		q = Hash.new {|h, k| h[k] = []}

		scan_query(query).each do |token|
			if token =~ /^(after_id|user|fav|md5|rating|name|width|height|score|source|unlocked):(.+)$/
				if $1 == "user"
					q[:user] = $2
				elsif $1 == "after_id"
					q[:after_id] = $2.to_i
				elsif $1 == "fav"
					q[:fav] = $2
				elsif $1 == "md5"
					q[:md5] = $2
				elsif $1 == "rating"
					q[:rating] = $2
				elsif $1 == "name"
					q[:include] << $2
					split_name = $2.split("_")

					if split_name.size == 2
						q[:include] << split_name.reverse.join("_")
						q[:include] << split_name[0]
						q[:include] << split_name[1]
					else
						split_name[0].gsub!('\\', '\\\\')
						split_name[0].gsub!('_', '\\_')
						split_name[0].gsub!('%', '\\%')

						q[:include] += find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\' OR name LIKE ? ESCAPE '\\\\'", split_name[0] + '\\_%', '%\\_' + split_name[0]]).map {|i| i.name}
					end
				elsif $1 == "width"
					width = $2;
					if width =~ /^([><]=?)(\d+)$/
						q[:width] = $2.to_i
						q[:widthop] = $1
					else
						q[:width] = width.to_i
						q[:widthop] = "="
					end
				elsif $1 == "height"
					height = $2;
					if height =~ /^([><]=?)(\d+)$/
						q[:height] = $2.to_i
						q[:heightop] = $1
					else
						q[:height] = height.to_i
						q[:heightop] = "="
					end
				elsif $1 == "score"
					score = $2;
					if score =~ /^([><]=?)(\d+)$/
						q[:score] = $2.to_i
						q[:scoreop] = $1
					else
						q[:score] = score.to_i
						q[:scoreop] = "="
					end
				elsif $1 == "source"
					q[:source] = $2.gsub('\\', '\\\\').gsub('%', '\\%').gsub('_', '\\_') + "%"
				end
			elsif token[0] == ?-
				q[:exclude] << token[1..-1]
			elsif token[0] == ?~
				q[:include] << token[1..-1]
			elsif token.include?("*")
				q[:include] += find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\'", token.gsub('\\', '\\\\').gsub('_', '\\_').gsub('%', '\\%').tr("*", "%")], :select => "name, post_count").map {|i| i.name}
			elsif token == "unlockedrating"
				q[:unlocked_rating] = true
			else
				q[:related] << token
			end
		end

		q[:exclude] = to_aliased(q[:exclude])
		q[:include] = to_aliased(q[:include])
		q[:related] = to_aliased(q[:related])

		return q
	end
end
