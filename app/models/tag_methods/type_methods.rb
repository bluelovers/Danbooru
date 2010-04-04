module TagMethods
  module TypeMethods
    module ClassMethods
      attr_accessor :type_map

      # Returns the text representation of a tag type value.
      def type_name_from_value(type_value)
        type_map[type_value]
      end

      def type_value(tag_name)
        Cache.get("tag_type:#{Cache.sanitize_key(tag_name)}", 24.hours) do
          tag_name.gsub!(/\s/, "_")
          tag_type = select_value_sql("SELECT tag_type FROM tags WHERE name = ?", tag_name)

          if tag_type.nil?
            0
          else
            tag_type.to_i
          end
        end
      end
      
      # Returns the text representation of a tag's type value.
      def type_name(tag_name)
        type_map[type_value(tag_name)]
      end

      # Returns the tag type and post count of a tag.
      def type_and_count(tag_name)
        Cache.get("tag_type_count:#{Cache.sanitize_key(tag_name)}", 24.hour) do
          results = select_all_sql("SELECT tag_type, post_count FROM tags WHERE name = ?", tag_name)
          if results.any?
            [results[0]["tag_type"].to_i, results[0]["post_count"].to_i]
          else
            [0, 0]
          end
        end
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.before_save :update_type

      # This maps ids to names
      m.type_map = CONFIG["tag_types"].keys.select {|x| x =~ /^[A-Z]/}.inject({}) {|all, x| all[CONFIG["tag_types"][x]] = x.downcase; all}
    end
    
    def update_type
      if tag_type_changed?
        original_type_name = Tag.type_name_from_value(tag_type_was)
        revised_type_name = Tag.type_name_from_value(tag_type)
        
        Post.find_by_tags(name).each do |post|
          post.decrement("#{original_type_name.downcase}_tag_count")
          post.increment("#{revised_type_name.downcase}_tag_count")
          post.save
        end
        
        Cache.delete("tag_type:#{Cache.sanitize_key(name)}")
        Cache.delete("tag_type_count:#{Cache.sanitize_key(name)}")
      end
    end

    def type_name
      Tag.type_name_from_value(tag_type)
    end

    def pretty_type_name
      type_name.capitalize
    end
  end
end
