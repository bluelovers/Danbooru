Dir["#{RAILS_ROOT}/app/models/tag_methods/**/*.rb"].each {|x| require_dependency x}

class Tag < ActiveRecord::Base
  include TagMethods::TypeMethods
  include TagMethods::CacheMethods if CONFIG["enable_caching"]
  include TagMethods::RelatedTagMethods
  include TagMethods::ParseMethods
  
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

  def self.select_ambiguous(tags)
    return [] if tags.blank?

    return connection.select_values(Tag.sanitize_sql(["SELECT name FROM tags WHERE name IN (?) AND is_ambiguous = TRUE ORDER BY name", tags]))
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
