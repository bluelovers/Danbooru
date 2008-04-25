module TagMethods
  module TypeMethods
    module ClassMethods
      attr_accessor :type_map
  
      # Find the type name for a type value.
      #
      # === Parameters
      # * :type_value<Integer>:: The tag type value to search for
      def type_name_from_value(type_value)
        type_map[type_value]
      end

      def type_name_helper(tag_name) # :nodoc:
        tag = Tag.find(:first, :conditions => ["name = ?", tag_name], :select => "tag_type")

        if tag == nil
          "general"
        else
          type_map[tag.tag_type]
        end
      end

      # Find the tag type name of a tag.
      #
      # === Parameters
      # * :tag_name<String>:: The tag name to search for
      def type_name(tag_name)
        tag_name = tag_name.gsub(/\s/, "_")
        
        if CONFIG["enable_caching"]
          return Cache.get("tag_type:#{tag_name}", 1.day) do
            type_name_helper(tag_name)
          end
        else
          type_name_helper(tag_name)
        end
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
  
      # This maps ids to names
      m.type_map = CONFIG["tag_types"].keys.select {|x| x =~ /^[A-Z]/}.inject({}) {|all, x| all[CONFIG["tag_types"][x]] = x.downcase; all}    
    end

    def type_name
      self.class.type_name_from_value(tag_type)
    end

    def pretty_type_name
      type_name.capitalize
    end
  end
end