class Tag < ActiveRecord::Base
  serialize :cached_related
  after_create :update_related_tags!

  @@tag_types = {
    :general    => 0,
    "general"   => 0,
    "gen"       => 0,

    :artist     => 1,
    "artist"    => 1,
    "art"       => 1,

    :copyright  => 3,
    "copyright" => 3,
    "copy"      => 3,
    "co"        => 3,

    :character  => 4,
    "character" => 4,
    "char"      => 4,
    "ch"        => 4
  }

  class << self
    def types
      @@tag_types
    end

    def count_by_period(start, stop, options = {})
      options[:limit] ||= 50

      cond = ["p.created_at BETWEEN ? AND ? AND p.id = pt.post_id AND pt.tag_id = t.id"]

      if options[:safe_mode]
        cond << "p.rating = 's'"
      end

      counts = connection.select_all(sanitize_sql(["SELECT COUNT(pt.tag_id) AS post_count, (SELECT name FROM tags WHERE id = pt.tag_id) AS name FROM posts p, posts_tags pt, tags t WHERE " + cond.join(" and ") + " GROUP BY pt.tag_id ORDER BY post_count DESC LIMIT #{options[:limit]}", start, stop]))
    end

    def find_or_create_by_name(name)
      if name =~ /^ambiguous:|^amb:(.+)/
        is_amb = true
        name = $1
      else
        is_amb = false
      end

      tag_type = @@tag_types[name[/^(.+?):/, 1]]
      if tag_type == nil
        tag_type = Tag.types[:general]
      else
        name.gsub!(/^.+?:/, "")
      end

      t = Tag.find_by_name(name)
      if t != nil
        if t.tag_type == Tag.types[:general] && t.tag_type != tag_type
          t.update_attributes(:tag_type => tag_type, :is_ambiguous => is_amb)
        end
        return t
      end

      Tag.create(:name => name, :tag_type => tag_type, :cached_related_expires_on => Time.now.yesterday, :is_ambiguous => is_amb)
    end

    def calculate_related_by_type(tag, type, limit = 25)
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS name,
        COUNT(pt0.tag_id) AS post_count
        FROM posts_tags pt0, posts_tags pt1
        WHERE pt0.post_id = pt1.post_id
        AND pt1.tag_id = (SELECT id FROM tags WHERE name = ?)
        AND pt0.tag_id IN (SELECT id FROM tags WHERE tag_type = ?)
        GROUP BY pt0.tag_id
        ORDER BY post_count DESC
        LIMIT #{limit}
      EOS

      return connection.select_all(Tag.sanitize_sql([sql, tag, type]))
    end

    def calculate_related(tags)
      tags = [*tags]
      return [] if tags.empty?

      if CONFIG["enable_related_tag_intersection"] == true
        from = ["posts_tags pt0"]
        cond = ["pt0.post_id = pt1.post_id"]
        sql = ""

        (1..tags.size).each {|i| from << "posts_tags pt#{i}"}
        (2..tags.size).each {|i| cond << "pt1.post_id = pt#{i}.post_id"}
        (1..tags.size).each {|i| cond << "pt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"}

        sql << "SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS tag, COUNT(pt0.*) AS tag_count"
        sql << " FROM " << from.join(", ")
        sql << " WHERE " << cond.join(" AND ")
        sql << " GROUP BY pt0.tag_id"
        sql << " ORDER BY tag_count DESC LIMIT 25"
        return connection.select_all(Tag.sanitize_sql([sql, *tags])).map {|x| [x["tag"], x["tag_count"]]}
      else
        return tags.inject([]) do |all, x|
          sql = ""
          sql << "SELECT (SELECT name FROM tags WHERE id = pt0.tag_id) AS tag, COUNT(pt0.*) AS tag_count"
          sql << " FROM posts_tags pt0, posts_tags pt1"
          sql << " WHERE pt1.post_id = pt0.post_id"
          sql << " AND pt1.tag_id = (SELECT id FROM tags WHERE name = ?)"
          sql << " GROUP by pt0.tag_id"
          sql << " ORDER BY tag_count DESC"
          sql << " LIMIT 25"
          all += connection.select_all(Tag.sanitize_sql([sql, x]))
        end
      end
    end

    def find_related(tags)
      if tags.is_a?(Array) && tags.size > 1
        return calculate_related(tags)
      else
        t = Tag.find_by_name(tags.to_s)
        if t
          return t.related
        else
          return []
        end
      end
    end

    def select_ambiguous(tags)
      return [] if tags.blank?

      tags = Tag.scan_tags(tags)
      return connection.select_values(Tag.sanitize_sql(["SELECT name FROM tags WHERE name IN (?) AND is_ambiguous = TRUE ORDER BY name", tags]))
    end

    def update_cached_tags(tags)
      post_ids = connection.select_values(Tag.sanitize_sql(["SELECT pt.post_id FROM posts_tags pt, tags t WHERE pt.tag_id = t.id AND t.name IN (?)", tags]))
      transaction do
        post_ids.each do |i|
          tags = connection.select_values("SELECT t.name FROM tags t, posts_tags pt WHERE t.id = pt.tag_id AND pt.post_id = #{i} ORDER BY t.name").join(" ")
          connection.execute(Tag.sanitize_sql(["UPDATE posts SET cached_tags = ? WHERE id = ?", tags, i]))
        end
      end
    end

    def scan_query(query)
      query.to_s.downcase.scan(/\S+/).uniq
    end

    def scan_tags(tags)
      tags.to_s.gsub(/[*%,]/, "").downcase.scan(/\S+/).map {|x| x.gsub(/^[-~]+/, "")}.uniq
    end

    def parse_helper(range, type = :integer)
      cast = lambda do |x|
        if type == :integer
          x.to_i
        elsif type == :date
          x.to_date
        end
      end

      case range
      when /^([-\d]+)\.\.([-\d]+)$/
        return [:between, cast[$1], cast[$2]]

      when /^\.\.([-\d]+)$/, /^<=?([-\d]+)$/
        return [:lt, cast[$1]]

      when /^([-\d]+)\.\.$/, /^>=?([-\d]+)$/
        return [:gt, cast[$1]]

      when /^([-\d]+)$/
        return [:eq, cast[$1]]

      else
        []

      end
    end

# Parses a query into three sets of tags: reject, union, and intersect.
#
# === Parameters
# * +query+: String, array, or nil. The query to parse.
# * +options+: A hash of options.
    def parse_query(query, options = {})
      q = Hash.new {|h, k| h[k] = []}

      scan_query(query).each do |token|
        if token =~ /^(user|fav|md5|-rating|rating|width|height|score|source|id|date|pool):(.+)$/
          if $1 == "user"
            q[:user] = $2
          elsif $1 == "fav"
            q[:fav] = $2
          elsif $1 == "md5"
            q[:md5] = $2
          elsif $1 == "-rating"
            q[:rating_negated] = $2
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
            q[:source] = $2.gsub('\\', '\\\\').gsub('%', '\\%').gsub('_', '\\_').gsub(/\*/, '%') + "%"
          elsif $1 == "date"
            q[:date] = parse_helper($2, :date)
					elsif $1 == "pool"
						q[:pool] = $2
          end
        elsif token[0] == ?-
          q[:exclude] << token[1..-1]
        elsif token[0] == ?~
          q[:include] << token[1..-1]
        elsif token.include?("*")
          q[:include] += find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\'", token.to_escaped_for_sql_like], :select => "name, post_count").map {|i| i.name}
        elsif token == "@unlockedrating"
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
  end

  def update_related_tags!(length = CONFIG["min_related_tags_cache_duration"])
    connection.execute(Tag.sanitize_sql(["UPDATE tags SET cached_related = ?, cached_related_expires_on = ? WHERE id = #{id}", Tag.calculate_related(self.name).to_yaml, length.hours.from_now]))
  end

  def related
    if Time.now > self.cached_related_expires_on
      length = (self.post_count / 20).to_i
      length = CONFIG["min_related_tags_cache_duration"] if length < CONFIG["min_related_tags_cache_duration"]

      self.update_related_tags!(length)
      self.reload
    end

    return self.cached_related
  end

  def to_s
    name
  end

  def <=>(rhs)
    name <=> rhs.name
  end

  def to_xml(options = {})
    {:id => id, :name => name, :count => post_count, :type => tag_type, :ambiguous => is_ambiguous}.to_xml(options.merge(:root => "tag"))
  end

  def to_json(options = {})
    {:id => id, :name => name, :count => post_count, :type => tag_type, :ambiguous => is_ambiguous}.to_json(options)
  end
end
