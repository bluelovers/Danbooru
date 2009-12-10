module UserMethods
  module ForumMethods
    def has_forum_been_updated?
      is_privileged_or_higher? && ForumPost.updated?(self)
    end
  end
end
