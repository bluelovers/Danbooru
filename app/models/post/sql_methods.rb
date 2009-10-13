module PostSqlMethods
  module ClassMethods
    def find_by_tag_join(tag, options = {})
      tag = tag.downcase.tr(" ", "_")
      find(:all, :conditions => ["tags.name = ? AND posts.status <> 'deleted'", tag], :select => "posts.*", :joins => "JOIN posts_tags ON posts_tags.post_id = posts.id JOIN tags ON tags.id = posts_tags.tag_id", :limit => options[:limit], :offset => options[:offset], :order => (options[:order] || "posts.id DESC"))
    end
    
    def generate_sql_post_count_helper(tags)
      tags.inject(0) do |sum, tag|
        sum + Post.fast_count(tag)
      end
    end
    
    def generate_sql_range_helper(arr, field, c, p)
      case arr[0]
      when :eq
        c << "#{field} = ?"
        p << arr[1]

      when :gt
        c << "#{field} > ?"
        p << arr[1]
  
      when :gte
        c << "#{field} >= ?"
        p << arr[1]

      when :lt
        c << "#{field} < ?"
        p << arr[1]

      when :lte
        c << "#{field} <= ?"
        p << arr[1]

      when :between
        c << "#{field} BETWEEN ? AND ?"
        p << arr[1]
        p << arr[2]

      else
        # do nothing
      end
    end
    
    def generate_sql_escape_helper(array)
      array.map do |token|
        escaped_token = token.gsub(/\\|'/, '\0\0\0\0').gsub("?", "\\\\77").gsub("%", "\\\\37")
        "''" + escaped_token + "''"
      end
    end

    def generate_sql(q, options = {})
      original_query = q

      unless q.is_a?(Hash)
        q = Tag.parse_query(q)
      end

      conds = ["true"]
      joins = ["posts p"]
      join_params = []
      cond_params = []

      generate_sql_range_helper(q[:post_id], "p.id", conds, cond_params)
      generate_sql_range_helper(q[:mpixels], "p.width*p.height/1000000.0", conds, cond_params)
      generate_sql_range_helper(q[:width], "p.width", conds, cond_params)
      generate_sql_range_helper(q[:height], "p.height", conds, cond_params)
      generate_sql_range_helper(q[:score], "p.score", conds, cond_params)
      generate_sql_range_helper(q[:filesize], "p.file_size", conds, cond_params)
      generate_sql_range_helper(q[:date], "p.created_at::date", conds, cond_params)
      generate_sql_range_helper(q[:change], "p.change_seq", conds, cond_params)
      generate_sql_range_helper(q[:general_tag_count], "p.general_tag_count", conds, cond_params)
      generate_sql_range_helper(q[:artist_tag_count], "p.artist_tag_count", conds, cond_params)
      generate_sql_range_helper(q[:copyright_tag_count], "p.copyright_tag_count", conds, cond_params)
      generate_sql_range_helper(q[:character_tag_count], "p.character_tag_count", conds, cond_params)

      if q[:md5].is_a?(String)
        conds << "p.md5 IN (?)"
        cond_params << q[:md5].split(/,/)
      end
      
      if q[:status].is_a?(String) and Post::STATUSES.member?(q[:status])
        conds << "p.status = ?"
        cond_params << q[:status]
      else
        conds << "p.status <> 'deleted'"
      end

      if q[:parent_id].is_a?(Integer)
        conds << "(p.parent_id = ? or p.id = ?)"
        cond_params << q[:parent_id]
        cond_params << q[:parent_id]
      elsif q[:parent_id] == false
        conds << "p.parent_id is null"
      end

      if q[:source].is_a?(String)
        conds << "p.source LIKE ? ESCAPE E'\\\\'"
        cond_params << q[:source]
      end

      if q[:subscriptions].is_a?(String)
        q[:subscriptions] =~ /^(.+?):(.+)$/
        username = $1 || q[:subscriptions]
        subscription_name = $2

        user = User.find_by_name(username)

        if user
          post_ids = TagSubscription.find_post_ids(user.id, subscription_name)
          conds << "p.id IN (?)"
          cond_params << post_ids
        end
      end

      if q[:fav].is_a?(String)
        joins << "JOIN favorites f ON f.post_id = p.id JOIN users fu ON f.user_id = fu.id"
        conds << "lower(fu.name) = lower(?)"
        cond_params << q[:fav]
        q[:order] = "fav" unless q[:order].is_a?(String)
      end
      
      if q[:user].is_a?(String)
        joins << "JOIN users u ON p.user_id = u.id"
        conds << "lower(u.name) = lower(?)"
        cond_params << q[:user]
      end

      if q[:pool].is_a?(String)
        joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
        conds << "pools.name ILIKE ? ESCAPE E'\\\\'"
        cond_params << ("%" + q[:pool].to_escaped_for_sql_like + "%")
      elsif q[:pool].is_a?(Integer)
        joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
        conds << "pools.id = ?"
        cond_params << q[:pool]
      end

      tags_index_query = []

      if q[:include].any?
        tags_index_query << "(" + generate_sql_escape_helper(q[:include]).join(" | ") + ")"
      end
      
      if q[:related].any?
        raise "You cannot search for more than #{CONFIG['tag_query_limit']} tags at a time" if q[:related].size > CONFIG["tag_query_limit"]
        tags_index_query << "(" + generate_sql_escape_helper(q[:related]).join(" & ") + ")"
      end

      if q[:exclude].any?
        raise "You cannot search for more than #{CONFIG['tag_query_limit']} tags at a time" if q[:exclude].size > CONFIG["tag_query_limit"]

        if q[:related].any? || q[:include].any?
          tags_index_query << "!(" + generate_sql_escape_helper(q[:exclude]).join(" | ") + ")"
        elsif options[:user] && options[:user].is_member_or_lower?
          raise "You cannot search for only excluded tags"
        else
          q[:exclude].each_with_index do |etag, i|
            joins << "LEFT JOIN posts_tags ept#{i} ON p.id = ept#{i}.post_id AND ept#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"
            conds << "ept#{i}.tag_id IS NULL"
            join_params << etag
          end
        end
      end

      if tags_index_query.any?
        conds << "tags_index @@ to_tsquery('danbooru', E'" + tags_index_query.join(" & ") + "')"
      end

      if q[:rating].is_a?(String)
        case q[:rating][0, 1].downcase
        when "s"
          conds << "p.rating = 's'"

        when "q"
          conds << "p.rating = 'q'"

        when "e"
          conds << "p.rating = 'e'"
        end
      end

      if q[:rating_negated].is_a?(String)
        case q[:rating_negated][0, 1].downcase
        when "s"
          conds << "p.rating <> 's'"

        when "q"
          conds << "p.rating <> 'q'"

        when "e"
          conds << "p.rating <> 'e'"
        end
      end

      if q[:unlocked_rating] == true
        conds << "p.is_rating_locked = FALSE"
      end

      sql = "SELECT "

      if options[:count]
        sql << "COUNT(*)"
      elsif options[:select]
        sql << options[:select]
      else
        sql << "p.*"
      end

      sql << " FROM " + joins.join(" ")
      sql << " WHERE " + conds.join(" AND ")

      if q[:order] && !options[:count]
        case q[:order]
        when "id", "id_asc"
          sql << " ORDER BY p.id"
      
        when "id_desc"
          sql << " ORDER BY p.id DESC"
      
        when "score", "score_desc"
          sql << " ORDER BY p.score DESC, p.id DESC"
      
        when "score_asc"
          sql << " ORDER BY p.score, p.id DESC"
      
        when "mpixels", "mpixels_desc"
          # Use "w*h/1000000", even though "w*h" would give the same result, so this can use
          # the posts_mpixels index.
          sql << " ORDER BY width*height/1000000.0 DESC, p.id DESC"

        when "mpixels_asc"
          sql << " ORDER BY width*height/1000000.0, p.id DESC"

        when "portrait"
          sql << " ORDER BY 1.0*width/GREATEST(1, height), p.id DESC"

        when "landscape"
          sql << " ORDER BY 1.0*width/GREATEST(1, height) DESC, p.id DESC"

        when "change", "change_asc"
          sql << " ORDER BY change_seq, p.id DESC"

        when "change_desc"
          sql << " ORDER BY change_seq DESC, p.id DESC"

        when "fav"
          if q[:fav].is_a?(String)
            sql << " ORDER BY f.id DESC"
          else
            sql << " ORDER BY p.id DESC"
          end
          
        when "favcount"
          sql << " ORDER BY p.fav_count DESC"
	
	when "filesize", "filesize_desc"
	  sql << " ORDER BY p.file_size DESC"

	when "filesize_asc"
	  sql << " ORDER BY p.file_size ASC"

        else
          sql << " ORDER BY p.id DESC"
        end
      end

      if options[:limit]
        sql << " LIMIT " + options[:limit].to_s
      end

      if options[:offset]
        sql << " OFFSET " + options[:offset].to_s
      end
      
      params = join_params + cond_params

      return Post.sanitize_sql([sql, *params])
    end
  end
  
  def self.included(m)
    m.extend(ClassMethods)
  end
end
