class Tag < ActiveRecord::Base
	serialize :cached_related
	after_create :related

	TYPES = {
		0 => "general",
		1 => "artist",
		2 => "ambiguous",
		3 => "copyright",
		4 => "character"
	}

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

	def self.type_string_to_integer(name)
		case name
		when "general"
			return TYPE_GENERAL

		when "artist"
			return TYPE_ARTIST

		when "character"
			return TYPE_CHARACTER

		when "copyright"
			return TYPE_COPYRIGHT

		when "ambiguous"
			return TYPE_AMBIGUOUS
		end

		return nil
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

	def self.find_related(tags)
		if tags.is_a?(Array) && tags.size > 1
			return [] if tags.empty?

			if CONFIG["enable_related_tag_intersection"] == true
				from = ["posts_tags pt0"]
				cond = ["pt0.post_id = pt1.post_id"]
				sql = ""

				(1..tags.size).each {|i| from << "posts_tags pt#{i}"}
				(2..tags.size).each {|i| cond << "pt1.post_id = pt#{i}.post_id"}
				(1..tags.size).each {|i| cond << "pt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"}

				sql << "SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS tag, COUNT(pt0.tag_id) AS tag_count"
				sql << " FROM " << from.join(", ")
				sql << " WHERE " << cond.join(" AND ")
				sql << " GROUP BY pt0.tag_id"
				sql << " ORDER BY tag_count DESC LIMIT 25"
				return connection.select_all(Tag.sanitize_sql([sql, *tags])).map {|x| [x["tag"], x["tag_count"]]}
			else
				return tags.inject([]) {|all, x| all += Tag.find_related(x)}
			end
		else
			t = Tag.find_by_name(tags.to_s)
			if t
				t.related
			else
				[]
			end
		end
	end

	def self.select_ambiguous(tags)
		return [] if tags.blank?

		tags = Tag.scan_tags(tags)
		return connection.select_values(Tag.sanitize_sql(["SELECT name FROM tags WHERE name IN (?) AND tag_type = 2 ORDER BY name", tags]))
	end

	def self.update_cached_tags(tags)
		post_ids = connection.select_values(Tag.sanitize_sql(["SELECT pt.post_id FROM posts_tags pt, tags t WHERE pt.tag_id = t.id AND t.name IN (?)", tags]))
		transaction do
			post_ids.each do |i|
				tags = connection.select_values("SELECT t.name FROM tags t, posts_tags pt WHERE t.id = pt.tag_id AND pt.post_id = #{i} ORDER BY t.name").join(" ")
				connection.execute(Tag.sanitize_sql(["UPDATE posts SET cached_tags = ? WHERE id = ?", tags, i]))
			end
		end
	end
	
	def related
		if Time.now > self.cached_related_expires_on
			length = (self.post_count / 20).to_i
			length = 8 if length < 8

			connection.execute(Tag.sanitize_sql(["UPDATE tags SET cached_related = ?, cached_related_expires_on = ? WHERE id = #{id}", Tag.find_related(self.name).to_yaml, length.hours.from_now]))
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
		tags.to_s.gsub(/[*%,]/, "").downcase.scan(/\S+/).map {|x| x.gsub(/^[-~]+/, "")}.uniq
	end

	def self.parse_helper(range)
		case range
		when /^(\d+)\.\.(\d+)$/
			return [:between, $1.to_i, $2.to_i]

		when /^\.\.(\d+)$/
			return [:lt, $1.to_i]

		when /^(\d+)\.\.$/
			return [:gt, $1.to_i]

		when /^(\d+)$/
			return [:eq, $1.to_i]

		else
			[]

		end
	end

# Parses a query into three sets of tags: reject, union, and intersect.
#
# === Parameters
# * +query+: String, array, or nil. The query to parse.
# * +options+: A hash of options.
	def self.parse_query(query, options = {})
		q = Hash.new {|h, k| h[k] = []}

		scan_query(query).each do |token|
			if token =~ /^(after_id|user|fav|md5|rating|width|height|score|source|unlocked|id):(.+)$/
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
				elsif $1 == "id"
					q[:post_id] = parse_helper($2)
				elsif $1 == "width"
					q[:width] = parse_helper($2)
				elsif $1 == "height"
					q[:height] = parse_helper($2)
				elsif $1 == "score"
					q[:score] = parse_helper($2)
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

		q[:exclude] = TagAlias.to_aliased(q[:exclude])
		q[:include] = TagAlias.to_aliased(q[:include])
		q[:related] = TagAlias.to_aliased(q[:related])

		return q
	end

	def tag_type=(s)
		case s
		when "ambiguous"
			self.tag_type = TYPE_AMBIGUOUS

		when "character"
			self.tag_type = TYPE_CHARACTER

		when "artist"
			self.tag_type = TYPE_ARTIST

		when "copyright"
			self.tag_type = TYPE_COPYRIGHT

		when "general"
			self.tag_type = TYPE_GENERAL

		when /^\d+$/
			self.tag_type = s.to_i
		end
	end

	def to_xml(options = {})
		attribs = {:id => self.id}

		options[:select].each do |x|
			case x
			when "name"
				attribs[:name] = self.name

			when "count"
				attribs[:count] = self.post_count

			when "type"
				attribs[:type] = self.tag_type

			end
		end

		return attribs.to_xml(options)
	end

	def to_json(options = {})
		attribs = {:id => self.id}

		options[:select].each do |x|
			case x
			when "name"
				attribs[:name] = self.name

			when "count"
				attribs[:count] = self.post_count
	
			when "type"
				attribs[:type] = self.tag_type

			end
		end

		return attribs.to_json(options)
	end
end
