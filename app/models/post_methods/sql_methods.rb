module PostMethods
  module SqlMethods
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
      generate_sql_range_helper(q[:date], "p.created_at::date", conds, cond_params)
      generate_sql_range_helper(q[:change], "p.change_seq", conds, cond_params)

      if q[:md5].is_a?(String)
        conds << "p.md5 IN (?)"
        cond_params << q[:md5].split(/,/)
      end
    
      if q[:deleted_only] == true
        conds << "p.status = 'deleted'"
      end

      if q[:parent_id].is_a?(Integer)
        conds << "(p.parent_id = ? or p.id = ?)"
        cond_params << q[:parent_id]
        cond_params << q[:parent_id]
      elsif q[:parent_id] == false
        conds << "p.parent_id is null"
      end

      if q[:source].is_a?(String)
        conds << "p.source LIKE ? ESCAPE '\\\\'"
        cond_params << ArtistUrl.normalize(q[:source])
      end

      if q[:fav].is_a?(String)
        joins << "JOIN favorites f ON f.post_id = p.id JOIN users fu ON f.user_id = fu.id"
        conds << "lower(fu.name) = lower(?)"
        cond_params << q[:fav]
      end

      if q[:user].is_a?(String)
        joins << "JOIN users u ON p.user_id = u.id"
        conds << "lower(u.name) = lower(?)"
        cond_params << q[:user]
      elsif q[:pool].is_a?(Integer)
        joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
        conds << "pools.id = ?"
        cond_params << q[:pool]
      end

      if q[:pool].is_a?(String)
        joins << "JOIN pools_posts ON pools_posts.post_id = p.id JOIN pools ON pools_posts.pool_id = pools.id"
        conds << "pools.name ILIKE ? ESCAPE '\\\\'"
        cond_params << ("%" + q[:pool].to_escaped_for_sql_like + "%")
      end

      if q[:include].any?
        joins << "JOIN posts_tags ipt ON ipt.post_id = p.id"
        conds << "ipt.tag_id IN (SELECT id FROM tags WHERE name IN (?))"
        cond_params << (q[:include] + q[:related])
      elsif q[:related].any?
        raise "You cannot search for more than #{CONFIG['tag_query_limit']} tags at a time" if q[:related].size > CONFIG["tag_query_limit"]
      
        q[:related].each_with_index do |rtag, i|
          joins << "JOIN posts_tags rpt#{i} ON rpt#{i}.post_id = p.id AND rpt#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"
          join_params << rtag
        end
      end

      if q[:exclude].any?
        raise "You cannot search for more than #{CONFIG['tag_query_limit']} tags at a time" if q[:exclude].size > CONFIG["tag_query_limit"]
        q[:exclude].each_with_index do |etag, i|
          joins << "LEFT JOIN posts_tags ept#{i} ON p.id = ept#{i}.post_id AND ept#{i}.tag_id = (SELECT id FROM tags WHERE name = ?)"
          conds << "ept#{i}.tag_id IS NULL"
          join_params << etag
        end
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

      if options[:pending]
        conds << "p.status = 'pending'"
      end
    
      if options[:flagged]
        conds << "p.status = 'flagged'"
      end

      if original_query.blank?
        conds << "p.parent_id is null"
      end

      sql = "SELECT "

      if options[:count]
        sql << "COUNT(*)"
      else
        sql << "p.*"
      end

      sql << " FROM " + joins.join(" ")
      sql << " WHERE " + conds.join(" AND ")

      if q[:order] && !options[:count]
        case q[:order]
        when "id"
          sql << " ORDER BY p.id"
        
        when "id_desc"
          sql << " ORDER BY p.id DESC"
        
        when "score"
          sql << " ORDER BY p.score DESC"
        
        when "score_asc"
          sql << " ORDER BY p.score"
        
        when "mpixels"
          sql << " ORDER BY width*height DESC"

        when "mpixels_asc"
          sql << " ORDER BY width*height"

        when "portrait"
          sql << " ORDER BY 1.0*width/GREATEST(1, height)"

        when "landscape"
          sql << " ORDER BY 1.0*width/GREATEST(1, height) DESC"

        when "change", "change_asc"
          sql << " ORDER BY change_seq"

        when "change_desc"
          sql << " ORDER BY change_seq DESC"

        when "fav"
          if q[:fav].is_a?(String)
            sql << " ORDER BY f.id DESC"
          end

        else
          sql << " ORDER BY p.id DESC"
        end
      elsif options[:order]
        sql << " ORDER BY " + options[:order]
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
end
