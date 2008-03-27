module PostMethods
  module CountMethods
    module ClassMethods
      def fast_count(tags = nil)
        if tags.blank?
          return connection.select_value("SELECT row_count FROM table_data WHERE name = 'posts'").to_i
        else
          c = connection.select_value(sanitize_sql(["SELECT post_count FROM tags WHERE name = ?", tags])).to_i
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
    end

    def increment_count
      connection.execute("UPDATE table_data SET row_count = row_count + 1 WHERE name = 'posts'")
    end

    def decrement_count
      connection.execute("UPDATE table_data SET row_count = row_count - 1 WHERE name = 'posts'")
    end
  end
end