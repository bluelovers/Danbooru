module PostCountMethods
  module ClassMethods
    def fast_count(tags = nil)
      if tags.blank?
        return select_value_sql("SELECT row_count FROM table_data WHERE name = 'posts'").to_i
      else
        c = select_value_sql("SELECT post_count FROM tags WHERE name = ?", tags).to_i
        if c == 0
          return Post.count_by_sql(Post.generate_sql(tags, :count => true))
        else
          return c
        end
      end
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
