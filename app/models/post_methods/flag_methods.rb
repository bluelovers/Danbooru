module PostMethods
  module FlagMethods
    class FlaggingError < Exception; end
    
    def flag!(reason, current_user)
      if reason.blank?
        raise FlaggingError.new("Must provide a reason")
      end
      
      if current_user.is_privileged_or_lower? && FlaggedPostDetail.count(:conditions => ["user_id = ? and created_at >= ?", current_user.id, 1.day.ago]) >= 10
        raise FlaggingError.new("Can only unapprove 10 posts a day")
      end

      if status != "active"
        raise FlaggingError.new("Can only unapprove active posts")
      end

      if flag_detail
        raise FlaggingError.new("This post has been previously unapproved and cannot be unapproved again")
      end

      update_attribute(:status, "flagged")

      if flag_detail
        flag_detail.update_attributes(:reason => reason, :user_id => creator_id)
      else
        FlaggedPostDetail.create!(:post_id => id, :reason => reason, :user_id => current_user.id, :is_resolved => false)
      end
    end
  end
end
