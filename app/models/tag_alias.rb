class TagAlias < ActiveRecord::Base
  before_create :normalize
  before_create :validate_uniqueness
  after_destroy :expire_cache
  after_create :expire_cache
  after_create :update_implications

  # Maps tags to their preferred names. Returns an array of strings.
  #
  # === Parameters
  # * :tag_names<Array<String>>:: list of tags to transform.
  def self.to_aliased(tag_names, options = {})
    tag_names.map {|x| to_aliased_single(x)}
  end
  
  def self.to_aliased_single(tag_name, options = {})
    Cache.get("tag_alias:#{tag_name}") do
      tag = select_value_sql("SELECT tags.name FROM tags JOIN tag_aliases ON tag_aliases.alias_id = tags.id WHERE tag_aliases.name = ? AND tag_aliases.is_pending = FALSE", tag_name)
      
      if tag
        tag
      else
        tag_name
      end
    end
  end
  
  def update_implications
    alias_predicate_id = Tag.find_or_create_by_name(name).id
    alias_consequent_id = alias_id
    
    TagImplication.find(:all, :conditions => ["predicate_id = ?", alias_predicate_id]).each do |impl|
      impl.update_attribute(:predicate_id, alias_consequent_id)
    end

    TagImplication.find(:all, :conditions => ["consequent_id = ?", alias_predicate_id]).each do |impl|
      impl.update_attribute(:consequent_id, alias_consequent_id)
    end
  end
  
  def expire_cache
    Cache.delete("tag_alias:#{name}")
  end
  
  # Destroys the alias and sends a message to the alias's creator.
  def destroy_and_notify(current_user, reason)
    if creator_id && creator_id != current_user.id
      msg = "A tag alias you submitted (#{name} &rarr; #{alias_name}) was deleted for the following reason: #{reason}."
      Dmail.create(:from_id => current_user.id, :to_id => creator_id, :title => "One of your tag aliases was deleted", :body => msg)
    end
    
    destroy
  end

  # Strips out any illegal characters and makes sure the name is lowercase.
  def normalize
    self.name = name.downcase.gsub(/ /, "_").gsub(/^[-~]+/, "")
  end

  # Makes sure the alias does not conflict with any other aliases.
  def validate_uniqueness
    if self.class.exists?(["name = ?", name])
      errors.add_to_base("#{name} is already aliased to something")
      return false
    end
    
    if self.class.exists?(["alias_id = (select id from tags where name = ?)", name])
      errors.add_to_base("#{name} is already aliased to something")
      return false
    end
    
    if self.class.exists?(["name = ?", alias_name])
      errors.add_to_base("#{alias_name} is already aliased to something")
      return false
    end
  end

  def alias=(name)
    alias_tag = Tag.find_or_create_by_name(name)
    tag = Tag.find_or_create_by_name(self.name)
    
    if alias_tag.tag_type != tag.tag_type && tag.tag_type != CONFIG["tag_types"]["General"]
      alias_tag.update_attribute(:tag_type, tag.tag_type)
    end
    
    self.alias_id = alias_tag.id
  end
  
  def alias_name
    Tag.find(alias_id).name
  end
  
  def alias_tag
    Tag.find_or_create_by_name(name)
  end

  def approve(user_id, ip_addr)
    key = name.tr(" ", "_")
    execute_sql("UPDATE tag_aliases SET is_pending = FALSE WHERE id = ?", id)
    Cache.delete("tag_alias:#{key}")

    Post.find(:all, :conditions => "tags_index @@ to_tsquery('danbooru', E'#{Post.generate_sql_escape_helper(name)}')").each do |post|
      post.reload
      post.update_attributes(:tags => post.cached_tags, :updater_user_id => user_id, :updater_ip_addr => ip_addr)
    end

    Cache.delete("post_count:#{key}")
    Cache.delete("post_count:#{Tag.find(alias_id).name}")
  end
  
  def api_attributes
    return {
     :id => id, 
     :name => name, 
     :alias_id => alias_id, 
     :pending => is_pending 
    }
  end

  def to_xml(options = {})
    api_attributes.to_xml(options.merge(:root => "alias"))
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end
end
