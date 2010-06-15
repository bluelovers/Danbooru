module UserMethods
  module BlacklistMethods
    # TODO: I don't see the advantage of normalizing these. Since commas are illegal
    # characters in tags, they can be used to separate lines (with whitespace separating
    # tags). Denormalizing this into a field in users would save a SQL query.
    def self.included(m)
      m.after_save :commit_blacklists
      m.after_create :set_default_blacklisted_tags
      m.has_many :user_blacklisted_tags, :dependent => :delete_all
      m.validate :validate_length_of_blacklisted_tags
    end
    
    def validate_length_of_blacklisted_tags
      if @blacklisted_tags && @blacklisted_tags.size > 3000
        self.errors.add :blacklisted_tags, "may not exceed 3000 characters in length"
        return false
      end
    end
    
    def blacklisted_tags=(blacklists)
      @blacklisted_tags = blacklists
    end

    def blacklisted_tags
      blacklisted_tags_array.join("\n") + "\n"
    end

    def blacklisted_tags_array
      user_blacklisted_tags.map {|x| x.tags}
    end

    def commit_blacklists
      if @blacklisted_tags
        user_blacklisted_tags.clear

        @blacklisted_tags.scan(/[^\r\n]+/).each do |tags|
          user_blacklisted_tags.create(:tags => tags)
        end
      end
    end
    
    def set_default_blacklisted_tags
      CONFIG["default_blacklists"].each do |b|
        UserBlacklistedTag.create(:user_id => self.id, :tags => b)
      end
    end
  end
end
