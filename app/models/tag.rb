class Tag < ActiveRecord::Base
  include TagMethods::TypeMethods
  include TagMethods::CacheMethods
  include TagMethods::RelatedTagMethods
  include TagMethods::ParseMethods
  include TagMethods::ApiMethods
  include TagMethods::ReportMethods
  
  attr_protected :cached_related, :cached_related_expires_on, :post_count
  
  def self.trending
    tags = Cache.get("$trending_tags", 1.hour) do
      arr = []
      tag_ids = select_values_sql("select pt.tag_id from posts_tags pt, posts p where pt.post_id = p.id and p.created_at >= ? group by pt.tag_id having count(*) > 10", 1.day.ago)

      tag_ids.each do |tag_id|
        tag = Tag.find(tag_id)
        recent = Tag.count(:conditions => ["p.created_at >= ? AND tags.id = ?", 1.day.ago, tag.id], :joins => "JOIN posts_tags pt ON pt.tag_id = tags.id JOIN posts p ON p.id = pt.post_id")
        arr << [tag, recent / tag.post_count.to_f, recent]
      end
      
      # [name, count, type]
      arr.sort_by {|x| -x[1]}.slice(0, 25).map {|x| [x[0].name, x[2], x[0].tag_type]}
    end
  end
  
  def self.count_by_period(start, stop, options = {})
    options[:limit] ||= 50
    counts = select_all_sql("SELECT COUNT(pt.tag_id) AS post_count, (SELECT name FROM tags WHERE id = pt.tag_id) AS name, t.tag_type AS tag_type FROM posts p, posts_tags pt, tags t WHERE p.created_at BETWEEN ? AND ? AND p.id = pt.post_id AND pt.tag_id = t.id GROUP BY pt.tag_id, t.tag_type ORDER BY post_count DESC LIMIT ?", start, stop, options[:limit]).map {|x| [x['name'], x['post_count'], x['tag_type'].to_i]}
  end
  
  def self.find_or_create_by_name(name, options = {})
    name = name.downcase.tr(" ", "_").gsub(/^[-~*]+/, "")
    
    ambiguous = false
    tag_type = nil
    
    if name =~ /^ambiguous:(.+)/
      ambiguous = true
      name = TagAlias.to_aliased($1).first
    end
    
    if name =~ /^(.+?):(.+)$/ && CONFIG["tag_types"][$1]
      tag_type = CONFIG["tag_types"][$1]
      name = TagAlias.to_aliased($2).first
    end
    
    tag = find_by_name(name)

    if tag
      if tag_type && !(options[:user] && options[:user].is_member_or_lower? && tag.post_count > 10)
        tag.update_attribute(:tag_type, tag_type)
      end
      
      if ambiguous
        tag.update_attribute(:is_ambiguous, ambiguous)
      end
      
      return tag
    else
      x = Tag.new(:name => name, :tag_type => tag_type || CONFIG["tag_types"]["General"], :is_ambiguous => ambiguous)
      x.cached_related_expires_on = Time.now
      x.save
      x
    end
  end

  def self.select_ambiguous(tags)
    return [] if tags.blank?
    return select_values_sql("SELECT name FROM tags WHERE name IN (?) AND is_ambiguous = TRUE ORDER BY name", tags)
  end

  def self.purge_tags
    sql =
      "DELETE FROM tags " +
      "WHERE post_count = 0 AND " +
      "id NOT IN (SELECT alias_id FROM tag_aliases UNION SELECT predicate_id FROM tag_implications UNION SELECT consequent_id FROM tag_implications)"
    execute_sql sql
  end

  def self.recalculate_post_count(tag_name = nil)
    if tag_name
      cond_params = [tag_name]
      cond = "WHERE tags.name = ?"
    else
      cond_params = []
      cond = ""
    end
    
    execute_sql "UPDATE tags SET post_count = (SELECT COUNT(*) FROM posts_tags pt, posts p WHERE pt.tag_id = tags.id AND pt.post_id = p.id AND p.status <> 'deleted') #{cond}", *cond_params
  end
  
  def self.mass_edit(start_tags, result_tags, updater_id, updater_ip_addr)
    Post.find_by_tags(start_tags).each do |p|
      start = TagAlias.to_aliased(Tag.scan_tags(start_tags))
      result = TagAlias.to_aliased(Tag.scan_tags(result_tags))
      tags = (p.cached_tags.scan(/\S+/) - start + result).join(" ")
      p.update_attributes(:updater_user_id => updater_id, :updater_ip_addr => updater_ip_addr, :tags => tags)
    end
  end
  
  def self.find_suggestions(query)
    if query.include?("_") && query.index("_") == query.rindex("_")
      # Contains only one underscore
      search_for = query.split(/_/).reverse.join("_").to_escaped_for_sql_like
    else
      search_for = "%" + query.to_escaped_for_sql_like + "%"
    end
    
    Tag.find(:all, :conditions => ["name LIKE ? ESCAPE E'\\\\' AND post_count > 0 AND name <> ?", search_for, query], :order => "post_count DESC", :limit => 6, :select => "name").map(&:name).sort
  end
end
