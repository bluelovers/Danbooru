module UserMethods
  module TagMethods
    def convert_flat_list_to_typed_list(list)
      if is_privileged_or_higher?
        list.scan(/\S+/).map do |x|
          t, c = Tag.type_and_count(x)
          [x, c, t]
        end
      else
        list.scan(/\S+/).map {|x| [x, 0, 0]}
      end
    end

    def uploaded_tags_with_types
      convert_flat_list_to_typed_list(uploaded_tags)
    end

    def recent_tags_with_types
      convert_flat_list_to_typed_list(recent_tags)
    end

    def calculate_uploaded_tags(tag_type)
      sql = <<-EOS
        SELECT 
          t.name
        FROM
          posts p,
          posts_tags pt,
          tags t
        WHERE
          p.user_id = ?
          AND p.id = pt.post_id
          AND pt.tag_id = t.id
          AND t.tag_type = ?
          AND p.created_at >= ?
        GROUP BY t.name
        ORDER BY COUNT(*) DESC
        LIMIT 10
      EOS

      return select_values_sql(sql, id, tag_type, 1.month.ago)
    end
    
=begin
    def uploaded_tags(options = {})
      type = options[:type]

      uploaded_tags = Cache.get("uploaded_tags/#{id}/#{type}")
      return uploaded_tags unless uploaded_tags == nil

      if RAILS_ENV == "test"
        # disable filtering in test mode to simplify tests
        popular_tags = ""
      else
        popular_tags = select_values_sql("SELECT id FROM tags WHERE tag_type = #{CONFIG['tag_types']['General']} ORDER BY post_count DESC LIMIT 8").join(", ")
        popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?
      end

      if type
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
          FROM posts_tags pt, tags t, posts p
          WHERE p.user_id = #{id}
          AND p.id = pt.post_id
          AND pt.tag_id = t.id
          #{popular_tags}
          AND t.tag_type = #{type.to_i}
          GROUP BY pt.tag_id
          ORDER BY count DESC
          LIMIT 6
        EOS
      else
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
          FROM posts_tags pt, posts p
          WHERE p.user_id = #{id}
          AND p.id = pt.post_id
          #{popular_tags}
          GROUP BY pt.tag_id
          ORDER BY count DESC
          LIMIT 6
        EOS
      end

      uploaded_tags = select_all_sql(sql)

      Cache.put("uploaded_tags/#{id}/#{type}", uploaded_tags, 1.day)

      return uploaded_tags
    end
=end
  end
end
