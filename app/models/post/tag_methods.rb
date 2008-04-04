module PostMethods
  module TagMethods
    attr_accessor :tags, :new_tags, :old_tags

    def self.included(m)
      m.after_save :commit_tags
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

    # Sets the tags for the post. Does not actually save anything to the database when called.
    #
    # === Parameters
    # * :tags<String>:: a whitespace delimited list of tags
    def tags=(tags)
      self.new_tags = Tag.scan_tags(tags)
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
      
      transaction do
        metatags, self.new_tags = new_tags.partition {|x| x=~ /^(?:-pool|pool|rating|parent):/}
        metatags.each do |metatag|
          case metatag
          when /^pool:(.+)/
            begin
              name = $1
              pool = Pool.find_by_name(name)
              pool.add_post(id) if pool
            rescue Pool::PostAlreadyExistsError
            end


          when /^-pool:(.+)/
            name = $1
            pool = Pool.find_by_name(name)
            pool.remove_post(id) if pool

          
          when /^rating:([qse])/
            execute_sql("UPDATE posts SET rating = ? WHERE id = ?", $1, id)


          when /^parent:(\d+)/
            parent_id = $1
          
            if CONFIG["enable_parent_posts"] && Post.exists?(parent_id)
              execute_sql("UPDATE posts SET parent_id = ? WHERE id = ?", parent_id, id)
            end
          end
        end

        self.new_tags << "tagme" if new_tags.empty?
        self.new_tags = TagAlias.to_aliased(new_tags)
        self.new_tags = TagImplication.with_implied(new_tags).uniq

        # TODO: be more selective in deleting from the join table
        execute_sql("DELETE FROM posts_tags WHERE post_id = ?", id)
        self.new_tags = new_tags.map {|x| Tag.find_or_create_by_name(x)}
        execute_sql("INSERT INTO posts_tags (post_id, tag_id) VALUES " + new_tags.map {|x| ("(#{id}, #{x.id})")}.join(", "))
        tag_string = new_tags.map(&:name).sort.join(" ")
        PostTagHistory.create(:post_id => id, :tags => tag_string, :user_id => updater_user_id, :ip_addr => updater_ip_addr)
        execute_sql("UPDATE posts SET cached_tags = ? WHERE id = ?", tag_string, id)
      end
    end
  end
end