module TagMethods
  module CacheMethods
    module ClassMethods
      def update_cached_tags(tags)
        post_ids = select_values_sql("SELECT pt.post_id FROM posts_tags pt, tags t WHERE pt.tag_id = t.id AND t.name IN (?)", tags)
        transaction do
          post_ids.each do |i|
            tags = select_values_sql("SELECT t.name FROM tags t, posts_tags pt WHERE t.id = pt.tag_id AND pt.post_id = #{i} ORDER BY t.name").join(" ")
            execute_sql("UPDATE posts SET cached_tags = ? WHERE id = ?", tags, i)
          end
        end
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.after_save :update_cache
    end

    def update_cache
      Cache.put("tag_type:#{name}", self.class.type_name_from_value(tag_type))
    end
  end
end
