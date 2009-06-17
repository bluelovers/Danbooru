module PostTagMethods
  attr_accessor :tags, :new_tags, :old_tags, :old_cached_tags

  module ClassMethods
    def find_by_tags(tags, options = {})
      return find_by_sql(Post.generate_sql(tags, options))
    end

    def recalculate_cached_tags(id = nil)
      conds = []
      cond_params = []

      sql = %{
        UPDATE posts p SET cached_tags = (
          SELECT array_to_string(coalesce(array(
            SELECT t.name
            FROM tags t, posts_tags pt
            WHERE t.id = pt.tag_id AND pt.post_id = p.id
            ORDER BY t.name
          ), '{}'::text[]), ' ')
        )
      }

      if id
        conds << "WHERE p.id = ?"
        cond_params << id
      end

      sql = [sql, conds].join(" ")
      execute_sql sql, *cond_params
    end
  end
  
  def self.included(m)
    m.extend ClassMethods
    m.after_save :commit_tags
    m.has_many :tag_history, :class_name => "PostTagHistory", :table_name => "post_tag_histories", :order => "id desc"
  end
  
  # === Parameters
  # * :tag<String>:: the tag to search for
  def has_tag?(tag)
    return cached_tags =~ /(^|\s)#{tag}($|\s)/
  end

  # Returns the tags in a URL suitable string
  def tag_title
    return cached_tags.gsub(/\W+/, "-")[0, 50]
  end
  
  def tags
    cached_tags
  end

  # Sets the tags for the post. Does not actually save anything to the database when called.
  #
  # === Parameters
  # * :tags<String>:: a whitespace delimited list of tags
  def tags=(tags)
    self.new_tags = Tag.scan_tags(tags)

    current_tags = cached_tags.scan(/\S+/)
    self.touch_change_seq! if new_tags != current_tags
  end
  
  # Commit any tag changes to the database.
  def commit_tags
    return if new_tags.nil?

    if old_tags
      # If someone else committed changes to this post before we did,
      # then try to merge the tag changes together.
      current_tags = cached_tags.scan(/\S+/)
      self.old_tags = Tag.scan_tags(old_tags)
      self.new_tags = (current_tags + new_tags) - old_tags + (current_tags & new_tags)
    end

    metatags, self.new_tags = new_tags.partition {|x| x=~ /^(?:-pool|pool|rating|parent):/}
    
    transaction do
      metatags.each do |metatag|
        case metatag
        when /^pool:(.+)/
          begin
            name = $1
            pool = Pool.find_by_name(name)
            
            if pool.nil? and name !~ /^\d+$/
              pool = Pool.new(:name => name, :description => "This pool was automatically generated", :is_public => false)
              pool.user_id = updater_user_id
              pool.save
            end

            pool.updater_user_id = updater_user_id
            pool.updater_ip_addr = updater_ip_addr
            pool.add_post(id, :user => User.find(updater_user_id)) if pool
          rescue Pool::PostAlreadyExistsError
          rescue Pool::AccessDeniedError
          end


        when /^-pool:(.+)/
          name = $1
          pool = Pool.find_by_name(name)
          if pool
            begin
              pool.remove_post(id, :user => User.find(updater_user_id))
            rescue Pool::AccessDeniedError
            end
          end

        
        when /^rating:([qse])/
          execute_sql("UPDATE posts SET rating = ? WHERE id = ?", $1, id)


        when /^parent:(\d*)/
          self.parent_id = $1
        
          if Post.exists?(parent_id)
            Post.set_parent(id, parent_id)
          end
        end
      end

      self.new_tags << "tagme" if new_tags.empty?
      self.new_tags = TagAlias.to_aliased(new_tags)
      self.new_tags = TagImplication.with_implied(new_tags).uniq

      # TODO: be more selective in deleting from the join table
      execute_sql("DELETE FROM posts_tags WHERE post_id = ?", id)
      self.new_tags = new_tags.map {|x| Tag.find_or_create_by_name(x)}.uniq

      # Tricky: Postgresql's locking won't serialize this DELETE/INSERT, so it's
      # possible for two simultaneous updates to both delete all tags, then insert
      # them, duplicating them all.
      #
      # Work around this by selecting the existing tags within the INSERT and removing
      # any that already exist.  Normally, the inner SELECT will return no rows; if
      # another process inserts rows before our INSERT, it'll return the rows that it
      # inserted and we'll avoid duplicating them.
      tag_set = new_tags.map {|x| ("(#{id}, #{x.id})")}.join(", ")
      #execute_sql("INSERT INTO posts_tags (post_id, tag_id) VALUES " + tag_set)
      sql = <<-EOS
        INSERT INTO posts_tags (post_id, tag_id)
        SELECT t.post_id, t.tag_id
         FROM (VALUES #{tag_set}) AS t(post_id, tag_id)
         WHERE t.tag_id NOT IN (SELECT tag_id FROM posts_tags pt WHERE pt.post_id = #{self.id})
      EOS

      execute_sql(sql)

      Post.recalculate_cached_tags(self.id)

      # Store the old cached_tags, so we can expire them.
      self.old_cached_tags = self.cached_tags
      self.cached_tags = select_value_sql("SELECT cached_tags FROM posts WHERE id = #{id}")

      PostTagHistory.create(:post_id => id, :rating => rating, :tags => cached_tags, :user_id => updater_user_id, :ip_addr => updater_ip_addr)
      self.new_tags = nil
    end
  end
end
