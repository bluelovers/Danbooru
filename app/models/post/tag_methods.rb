module PostMethods
  module TagMethods
    def has_tag?(tag)
      return self.cached_tags.scan(/\S+/).any? {|x| x == tag}
    end
  
    # Returns the tags in a URL suitable string
    def tag_title
      return self.cached_tags.gsub(/\W+/, "-")[0, 50]
    end

    def append_tags(t)
      @new_tags = self.cached_tags + " " + t
    end
  
    def tags
      if self.new_record?
        []
      else
        Tag.find(:all, :joins => "join posts_tags on tags.id = posts_tags.tag_id", :select => "tags.*", :conditions => "posts_tags.post_id = #{self.id}")
      end
    end

    def tags=(t)
      @new_tags = Tag.scan_tags(t)

      if self.old_tags
        # If someone else committed changes to this post before we did, 
        # try to merge the tag changes together.
        current_tags = self.cached_tags.scan(/\S+/)
        self.old_tags = Tag.scan_tags(self.old_tags)
        @new_tags = (current_tags + @new_tags) - self.old_tags + (current_tags & @new_tags)
      end

      # Process all the metatags that don't require post.id here (before we save the record)
      metatags, @new_tags = @new_tags.partition {|x| x =~ /^(?:rating|parent):/}
      metatags.each do |t|
        if t =~ /^rating:([qse])/ && $1 != self.rating
          self.rating = $1
        elsif CONFIG["enable_parent_posts"] && t =~ /^parent:(\d+)/
          self.parent_id = $1.to_i
        end
      end
    end
  
    # commits the tag changes to the database
    def commit_tags
      return if @new_tags == nil
    
      metatags, @new_tags = @new_tags.partition {|x| x=~ /^(?:-pool|pool):/}
      metatags.each do |t|
        if t =~ /^pool:(.+)/
          begin
            s = $1
          
            # NOTE: this will hide pools with names that are all numbers
            if s =~ /^\d+$/
              begin
                pool = Pool.find(s)
              rescue ActiveRecord::RecordNotFound
              end
            else
              pool = Pool.find(:first, :conditions => ["lower(name) = lower(?)", s])
            end
            pool.add_post(self.id) if pool
          rescue Pool::PostAlreadyExistsError
          end
        elsif t =~ /^-pool:(.+)/
          s = $1
          if s =~ /^\d+$/
            begin
              pool = Pool.find(s)
            rescue ActiveRecord::RecordNotFound
            end
          else
            pool = Pool.find(:first, :conditions => ["lower(name) = lower(?)", s])
          end
          pool.remove_post(self.id) if pool
        end
      end

      @new_tags << "tagme" if @new_tags.empty?
      @new_tags = TagAlias.to_aliased(@new_tags).uniq
      @new_tags = TagImplication.with_implied(@new_tags).uniq

      transaction do
        # TODO: be more selective in deleting from the join table
        connection.execute("DELETE FROM posts_tags WHERE post_id = #{self.id}")
        @new_tags = @new_tags.map {|x| Tag.find_or_create_by_name(x)}
        connection.execute("INSERT INTO posts_tags (post_id, tag_id) VALUES " + @new_tags.map {|x| ("(#{self.id}, #{x.id})")}.join(", "))

        tag_string = @new_tags.map {|x| x.name}.sort.join(" ")

        unless connection.select_value("SELECT tags FROM post_tag_histories WHERE post_id = #{id} ORDER BY id DESC LIMIT 1") == tag_string
          PostTagHistory.create(:post_id => self.id, :tags => tag_string, :user_id => self.updater_user_id, :ip_addr => self.updater_ip_addr)
        end
        connection.execute(Post.sanitize_sql(["UPDATE posts SET cached_tags = ? WHERE id = #{id}", tag_string]))
      end
    end
  end
end