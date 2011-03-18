module PostMethods
  module FlagMethods
    class FlaggingError < Exception; end
    
    def flag!(reason, current_user)
      if reason.blank?
        raise FlaggingError.new("Must provide a reason")
      end
      
      if current_user.is_privileged_or_lower? && PostFlag.count(:conditions => ["user_id = ? and created_at >= ?", current_user.id, 1.day.ago]) >= 10
        raise FlaggingError.new("Can only flag 10 posts a day")
      end

      if status == "deleted"
        raise FlaggingError.new("Can not flag deleted posts")
      end

      update_attribute(:status, "flagged")
      self.flags.create!(:post_id => id, :reason => reason, :user_id => current_user.id, :is_resolved => false)
    end
  end
end
