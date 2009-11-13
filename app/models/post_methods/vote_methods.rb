module PostMethods
  module VoteMethods
    class InvalidScoreError < Exception
    end
  
    class AlreadyVotedError < Exception
    end
  
    class PrivilegeError < Exception
    end

    def self.included(m)
      m.has_many :votes, :class_name => "PostVote"
    end
  
    def vote!(current_user, score)
      unless [1, -1].include?(score)
        raise InvalidScoreError
      end

      if current_user.is_member_or_lower?
        raise PrivilegeError
      end
    
      if PostVote.exists?(["user_id = ? AND post_id = ?", current_user.id, id])
        raise AlreadyVotedError
      end

      self.score += score
      transaction do
        execute_sql("UPDATE posts SET score = ? WHERE id = ?", self.score, id)
        votes.create(:user_id => current_user.id, :score => score)
      end
    end
  end
end
