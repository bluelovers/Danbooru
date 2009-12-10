module UserMethods
  module InviteMethods
    class InvitationError < Exception ; end
    
    def invite!(name, level)
      if invite_count <= 0
        raise InvitationError.new("You have no invites to give")
      end
      
      if level.to_i >= CONFIG["user_levels"]["Contributor"]
        level = CONFIG["user_levels"]["Contributor"]
      end
      
      invitee = User.find_by_name(name)
      
      if invitee.nil?
        raise ActiveRecord::RecordNotFound
      end
      
      if UserRecord.exists?(["user_id = ? AND is_positive = false AND reported_by IN (SELECT id FROM users WHERE level >= ?)", invitee.id, CONFIG["user_levels"]["Mod"]]) && !is_admin?
        raise InvitationError.new("Only mods can invite users with negative records")
      end
      
      transaction do
        if level == CONFIG["user_levels"]["Contributor"]
          Post.find(:all, :conditions => ["user_id = ? AND status = 'pending'", id]).each do |post|
            post.approve!(id)
          end
        end
        invitee.level = level
        invitee.invited_by = id
        invitee.save
        decrement! :invite_count
      end
    end
    
    def invited_by_name
      self.class.find_name(invited_by)
    end
    
    def self.included(m)
      m.attr_protected :invite_count
    end    
  end
end
