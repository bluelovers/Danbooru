module UserMethods
  module LimitMethods
    def self.included(m)
      m.attr_protected :base_upload_limit
    end
    
    def base_upload_limit
      bul = read_attribute(:base_upload_limit)
      if bul.nil?
        10
      else
        bul
      end
    end
    
    def can_upload?
      if is_contributor_or_higher?
        true
      elsif created_at > 1.week.ago
        false
      elsif upload_limit <= 0
        false
      else
        true
      end
    end
    
    def can_comment?
      if is_privileged_or_higher?
        true
      elsif created_at > 1.week.ago
        false
      elsif Comment.count(:conditions => ["user_id = ? AND created_at > ?", id, 1.hour.ago]) >= CONFIG["member_comment_limit"]
        false
      else
        true
      end      
    end
    
    def can_comment_vote?
      CommentVote.count(:conditions => ["user_id = ? and created_at >= ?", id, 1.hour.ago]) < 10
    end
    
    def can_remove_from_pools?
      if created_at > 1.week.ago
        false
      else
        true
      end
    end
    
    def upload_limit
      deleted_count = Post.count(:conditions => ["status = ? AND user_id = ?", "deleted", id])
      unapproved_count = Post.count(:conditions => ["status = ? AND user_id = ?", "pending", id])
      approved_count = Post.count(:conditions => ["status = ? AND user_id = ?", "active", id])
      
      limit = base_upload_limit + (approved_count / 10) - (deleted_count / 4) - unapproved_count
      
      if limit > 20
        limit = 20
      end
      
      if limit < 0
        limit = 0
      end
      
      limit
    end
  end
end
