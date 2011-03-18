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
    
    def is_resolved?
      flags.any? {|x| x.is_resolved?}
    end
    
    def approve!(current_user_id)
      if self.status == "active"
        return
      end
      
      if self.approver_id == current_user_id
        raise "You have previously approved this post and cannot approve it again"
      end
      
      flags.each {|x| x.update_attribute(:is_resolved, true)}

      self.status = "active"
      self.approver_id = current_user_id
      save
    end
  end
end
