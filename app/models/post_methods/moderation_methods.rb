module PostMethods
  module ModerationMethods
    def mod_hide!(user_id)
      unless ModQueuePost.exists?(["user_id = ? AND post_id = ?", user_id, id])
        ModQueuePost.create(:user_id => user_id, :post_id => id)
      end
    end
  
    def mod_hidden_count
      ModQueuePost.count(:conditions => ["post_id = ?", id])
    end
    
    def approve!(approver_id)
      user = User.find(approver_id)
      if !user.can_moderate?
        return false
      end
      
      if flag_detail
        flag_detail.update_attributes(:is_resolved => true)
      end

      self.status = "active"
      self.approver_id = approver_id
      save
    end
  end
end
