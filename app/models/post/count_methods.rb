module PostCountMethods
  module ClassMethods
    def fast_count(tags = nil)
      if tags.blank?
        return select_value_sql("SELECT row_count FROM table_data WHERE name = 'posts'").to_i
      else
        c = select_value_sql("SELECT post_count FROM tags WHERE name = ?", tags).to_i
        if c == 0
          key = Digest::MD5.hexdigest(tags)
          Cache.get("post_count:#{key}", 24.hours) do
            Post.count_by_sql(Post.generate_sql(tags, :count => true))
          end.to_i
        else
          return c
        end
      end
    end
    
    def fast_deleted_count(tags)
      if tags.blank?
        Cache.get("deleted_count", 24.hours) do
          select_value_sql("SELECT COUNT(*) FROM posts WHERE status = 'deleted'")
        end.to_i
      else
        key = Digest::MD5.hexdigest(tags)
        
        Cache.get("deleted_count:#{key}", 24.hours) do
          Post.count_by_sql(Post.generate_sql("#{tags} status:deleted", :count => true))
        end.to_i
      end
    end

    def recalculate_row_count
      execute_sql("UPDATE table_data SET row_count = (SELECT COUNT(*) FROM posts WHERE parent_id IS NULL AND status <> 'deleted') WHERE name = 'posts'")
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
    m.after_create :increment_count
    m.before_destroy :decrement_count      
  end

  def increment_count
    execute_sql("UPDATE table_data SET row_count = row_count + 1 WHERE name = 'posts'")
  end

  def decrement_count
    execute_sql("UPDATE table_data SET row_count = row_count - 1 WHERE name = 'posts'")
  end
end
