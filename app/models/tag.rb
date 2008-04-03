class Tag < ActiveRecord::Base
  # This maps integers to strings.
  @type_map = CONFIG["tag_types"].keys.select {|x| x =~ /^[A-Z]/}.inject({}) {|all, x| all[CONFIG["tag_types"][x]] = x.downcase; all}
  
  if CONFIG["enable_caching"]
    after_save :update_memcache
  end
  
  # Find the type name for a type value.
  def self.type_name_from_value(type_value)
    @type_map[type_value]
  end

  def self.type_name_helper(tag_name)
    tag = Tag.find(:first, :conditions => ["name = ?", tag_name], :select => "tag_type")
    
    if tag == nil
      "general"
    else
      @type_map[tag.tag_type]
    end
  end
  
  # Find the type for a tag. Returns a string.
  def self.type_name(tag_name)
    if CONFIG["enable_caching"]
      return Cache.get("tag_type:#{tag_name}", 1.day) do
        type_name_helper(tag_name)
      end
    else
      type_name_helper(tag_name)
    end
  end
  
  def self.count_by_period(start, stop, options = {})
    options[:limit] ||= 50

    cond = ["p.created_at BETWEEN ? AND ? AND p.id = pt.post_id AND pt.tag_id = t.id"]

    counts = connection.select_all(sanitize_sql(["SELECT COUNT(pt.tag_id) AS post_count, (SELECT name FROM tags WHERE id = pt.tag_id) AS name FROM posts p, posts_tags pt, tags t WHERE " + cond.join(" and ") + " GROUP BY pt.tag_id ORDER BY post_count DESC LIMIT #{options[:limit]}", start, stop]))
  end

  def self.find_or_create_by_name(name)
    name = name.downcase.tr(" ", "_").gsub(/^[-~]+/, "")
    
    ambiguous = false
    tag_type = nil
    
    if name =~ /^ambiguous:(.+)/
      ambiguous = true
      name = $1
    end
    
    if name =~ /^(.+?):(.+)$/ 
      if CONFIG["tag_types"][$1]
        tag_type = CONFIG["tag_types"][$1]
        name = $2
      end
    end

    tag = find_by_name(name)
    
    if tag
      if tag_type
        tag.update_attributes(:tag_type => tag_type)
      end
      
      if ambiguous
        tag.update_attributes(:is_ambiguous => ambiguous)
      end
      
      return tag
    else
      create(:name => name, :tag_type => tag_type || CONFIG["tag_types"]["General"], :cached_related_expires_on => Time.now, :is_ambiguous => ambiguous)
    end
  end

  def self.calculate_related_by_type(tag, type, limit = 25)
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

    return connection.select_all(sanitize_sql([sql, tag, type]))
  end

  def self.calculate_related(tags)
    tags = [*tags]
    return [] if tags.empty?

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

    return connection.select_all(sanitize_sql([sql, *tags])).map {|x| [x["tag"], x["tag_count"]]}
  end

  def self.find_related(tags)
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

  def self.select_ambiguous(tags)
    return [] if tags.blank?

    return connection.select_values(Tag.sanitize_sql(["SELECT name FROM tags WHERE name IN (?) AND is_ambiguous = TRUE ORDER BY name", tags]))
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

  def self.scan_query(query)
    query.to_s.downcase.scan(/\S+/).uniq
  end

  def self.scan_tags(tags)
    tags.to_s.gsub(/[*%,]/, "").downcase.scan(/\S+/).uniq
  end

  def self.parse_helper(range, type = :integer)
    cast = lambda do |x|
      if type == :integer
        x.to_i
      elsif type == :float
        x.to_f
      elsif type == :date
        x.to_date
      end
    end

    # "1", "0.5", "5.", ".5":
    # (-?(\d+(\.\d*)?|\d*\.\d+))
    case range
    when /^(.+?)\.\.(.+)/
      return [:between, cast[$1], cast[$2]]
 
    when /^<(.+)/
      return [:lt, cast[$1]]
      
    when /^<=(.+)/, /^\.\.(.+)/
      return [:lte, cast[$1]]
    
    when /^>(.+)/
      return [:gt, cast[$1]]
      
    when /^>=(.+)/, /^(.+)\.\.$/
      return [:gte, cast[$1]]

    else
      return [:eq, cast[range]]

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
      if token =~ /^(unlocked|deleted|user|fav|md5|-rating|rating|width|height|mpixels|score|source|id|date|pool|parent|order):(.+)$/
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
        elsif $1 == "mpixels"
          q[:mpixels] = parse_helper($2, :float)
        elsif $1 == "score"
          q[:score] = parse_helper($2)
        elsif $1 == "source"
          q[:source] = $2.gsub('\\', '\\\\').gsub('%', '\\%').gsub('_', '\\_').gsub(/\*/, '%') + "%"
        elsif $1 == "date"
          q[:date] = parse_helper($2, :date)
        elsif $1 == "pool"
          q[:pool] = $2
          if q[:pool] =~ /^(\d+)$/
            q[:pool] = q[:pool].to_i
          end
        elsif $1 == "parent"
          if $2 == "none"
            q[:parent_id] = false
          else
            q[:parent_id] = $2.to_i
          end
        elsif $1 == "order"
          q[:order] = $2
        elsif $1 == "unlocked"
          if $2 == "rating"
            q[:unlocked_rating] = true
          end
        elsif $1 == "deleted" && $2 == "true"
          q[:deleted_only] = true
        end
      elsif token[0] == ?-
        q[:exclude] << token[1..-1]
      elsif token[0] == ?~
        q[:include] << token[1..-1]
      elsif token.include?("*")
        q[:include] += find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\'", token.to_escaped_for_sql_like], :select => "name, post_count", :limit => 20).map {|i| i.name}
      elsif token == "@unlockedrating"
        q[:unlocked_rating] = true
      else
        q[:related] << token
      end
    end

    unless options[:skip_aliasing]
      q[:exclude] = TagAlias.to_aliased(q[:exclude])
      q[:include] = TagAlias.to_aliased(q[:include])
      q[:related] = TagAlias.to_aliased(q[:related])
    end

    return q
  end
  
  def update_related_tags(length)
    sql = Tag.sanitize_sql(["UPDATE tags SET cached_related = ?, cached_related_expires_on = ? WHERE id = #{id}", Tag.calculate_related(self.name).flatten.join(","), length.hours.from_now])
    connection.execute(sql)
  end

  def related
    if Time.now > self.cached_related_expires_on
      length = (self.post_count / 3).to_i
      length = 12 if length < 12
      length = 8760 if length > 8760

      self.update_related_tags(length)
      self.reload
    end

    return self.cached_related.split(/,/).in_groups_of(2)
  end

  def to_s
    name
  end

  def type_name
    self.class.type_name_from_value(tag_type)
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
  
  def update_memcache
    Cache.put("tag_type:#{name}", self.class.type_name_from_value(tag_type))
  end
end
