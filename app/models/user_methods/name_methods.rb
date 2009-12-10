module UserMethods
  module NameMethods
    module ClassMethods
      def find_name_helper(user_id)
        if user_id.nil?
          return CONFIG["default_guest_name"]
        end

        user = find(:first, :conditions => ["id = ?", user_id], :select => "name")

        if user
          return user.name
        else
          return CONFIG["default_guest_name"]
        end
      end

      def find_name(user_id)
        # TODO: do I really need this cache?
        
        if RAILS_ENV == "test"
          @cache = {}
        else
          @cache ||= {}
          @cache.clear if @cache.size > 30
          return @cache[user_id] if @cache[user_id]
        end
        
        @cache[user_id] = Cache.get("user_name:#{user_id}") do
          find_name_helper(user_id)
        end
      end
      
      def find_by_name(name)
        find(:first, :conditions => ["lower(name) = lower(?)", name])
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
      m.validates_length_of :name, :within => 2..20, :on => :create
      m.validates_format_of :name, :with => /\A[^\s;,]+\Z/, :on => :create, :message => "cannot have whitespace, commas, or semicolons"
      m.validates_uniqueness_of :name, :case_sensitive => false, :on => :create
      m.after_save :update_cached_name
    end
    
    def pretty_name
      name.tr("_", " ")
    end

    def update_cached_name
      Cache.put("user_name:#{id}", name)
    end
  end
end
