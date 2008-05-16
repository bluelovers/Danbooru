Dir["#{RAILS_ROOT}/app/models/tag/**/*.rb"].each {|x| require_dependency x}

class Tag < ActiveRecord::Base
  include TagTypeMethods
  include TagCacheMethods if CONFIG["enable_caching"]
  include TagRelatedTagMethods
  include TagParseMethods
  include TagApiMethods
  
  def self.count_by_period(start, stop, options = {})
    options[:limit] ||= 50
    counts = select_all_sql("SELECT COUNT(pt.tag_id) AS post_count, (SELECT name FROM tags WHERE id = pt.tag_id) AS name FROM posts p, posts_tags pt, tags t WHERE p.created_at BETWEEN ? AND ? AND p.id = pt.post_id AND pt.tag_id = t.id GROUP BY pt.tag_id ORDER BY post_count DESC LIMIT ?", start, stop, options[:limit])
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
end
