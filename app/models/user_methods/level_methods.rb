module UserMethods
  module LevelMethods
    def self.included(m)
      m.attr_protected :level
      m.before_create :set_role
    end
    
    def pretty_level
      return CONFIG["user_levels"].invert[self.level]
    end

    def set_role
      if User.fast_count == 0
        self.level = CONFIG["user_levels"]["Admin"]
      elsif CONFIG["enable_account_email_activation"]
        self.level = CONFIG["user_levels"]["Unactivated"]
      else
        self.level = CONFIG["starting_level"]
      end

      self.last_logged_in_at = Time.now
    end
    
    def has_permission?(record, foreign_key = :user_id)
      if is_mod_or_higher?
        true
      elsif record.respond_to?(foreign_key)
        record.__send__(foreign_key) == id
      else
        false
      end
    end

    # Defines various convenience methods for finding out the user's level
    CONFIG["user_levels"].each do |name, value|
      normalized_name = name.downcase.gsub(/ /, "_")
      define_method("is_#{normalized_name}?") do
        self.level == value
      end

      define_method("is_#{normalized_name}_or_higher?") do
        self.level >= value
      end

      define_method("is_#{normalized_name}_or_lower?") do
        self.level <= value
      end
    end
  end
end
