module UserMethods
  module CountMethods
    module ClassMethods
      def fast_count
        return select_value_sql("SELECT row_count FROM table_data WHERE name = 'users'").to_i
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
      m.after_create :increment_count
      m.after_destroy :decrement_count
    end
    
    def increment_count
      connection.execute("update table_data set row_count = row_count + 1 where name = 'users'")
    end

    def decrement_count
      connection.execute("update table_data set row_count = row_count - 1 where name = 'users'")
    end
  end
end
