class TagAlias < ActiveRecord::Base
  before_create :normalize
  before_create :validate_uniqueness

  def normalize
    self.name = self.name.downcase
  end

  def validate_uniqueness
    n = Tag.find_or_create_by_name(self.name)
    a = Tag.find(self.alias_id)

    if self.class.find(:first, :conditions => ["name = ? OR name = ? OR alias_id = ? OR alias_id = ?", n.name, a.name, n.id, a.id])
      self.errors.add_to_base("Alias already exists")
      return false
    end
  end

  def alias=(name)
    tag = Tag.find_or_create_by_name(name)
    self.alias_id = tag.id
  end

  def approve(user_id, ip_addr)
    transaction do
      connection.execute("UPDATE tag_aliases SET is_pending = FALSE WHERE id = #{self.id}")

      Post.find(:all, :conditions => Tag.sanitize_sql(["id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = (SELECT id FROM tags WHERE name = ?))", self.name])).each do |post|
        post.update_attributes(:tags => post.cached_tags, :updater_user_id => user_id, :updater_ip_addr => ip_addr)
      end
    end
  end

# Maps tag synonyms to their preferred names. Returns an array of strings.
  def self.to_aliased(tags)
    return [] if tags.blank?
    aliased = []

    [*tags].each do |t|
      aliased << connection.select_value(sanitize_sql([<<-SQL, t, t]))
        SELECT coalesce(
          (
            SELECT t.name 
            FROM tags t, tag_aliases ta 
            WHERE ta.name = ? 
            AND ta.alias_id = t.id
            AND ta.is_pending = FALSE
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

  def to_xml(options = {})
    {:id => id, :name => name, :alias_id => alias_id, :pending => is_pending}.to_xml(options.merge(:root => "tag_alias"))
  end

  def to_json(options = {})
    {:id => id, :name => name, :alias_id => alias_id, :pending => is_pending}.to_json(options)
  end
end
