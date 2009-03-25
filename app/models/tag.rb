Dir["#{RAILS_ROOT}/app/models/tag/**/*.rb"].each {|x| require_dependency x}

class Tag < ActiveRecord::Base
  include TagTypeMethods
  include TagCacheMethods
  include TagRelatedTagMethods
  include TagParseMethods
  include TagApiMethods
  
  def self.count_by_period(start, stop, options = {})
    options[:limit] ||= 50
    counts = select_all_sql("SELECT COUNT(pt.tag_id) AS post_count, (SELECT name FROM tags WHERE id = pt.tag_id) AS name, t.tag_type AS tag_type FROM posts p, posts_tags pt, tags t WHERE p.created_at BETWEEN ? AND ? AND p.id = pt.post_id AND pt.tag_id = t.id GROUP BY pt.tag_id, t.tag_type ORDER BY post_count DESC LIMIT ?", start, stop, options[:limit]).map {|x| TagProxy.new(x['name'], x['post_count'], Tag.type_name_from_value(x['tag_type'].to_i))}
  end

  def self.find_or_create_by_name(name)
    name = name.downcase.tr(" ", "_").gsub(/^[-~]+/, "")
    
    ambiguous = false
    tag_type = nil
    
    if name =~ /^ambiguous:(.+)/
      ambiguous = true
      name = $1
    end
    
    if name =~ /^(.+?):(.+)$/  && CONFIG["tag_types"][$1]
      tag_type = CONFIG["tag_types"][$1]
      name = $2
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
    
    Tag.find(:all, :conditions => ["name LIKE ? ESCAPE E'\\\\' AND name <> ?", search_for, query], :order => "post_count DESC", :limit => 6, :select => "name").map(&:name).sort
  end
end
