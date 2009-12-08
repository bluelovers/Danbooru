module PostMethods
  module VoteMethods
    class VotingError < Exception ; end

    def self.included(m)
      m.has_many :votes, :class_name => "PostVote"
    end
  
    def vote!(current_user, score)
      unless [1, -1].include?(score)
        raise VotingError.new("Invalid score")
      end

      if current_user.is_member_or_lower?
        raise VotingError.new("Only privileged members and above can vote")
      end
    
      if PostVote.exists?(["user_id = ? AND post_id = ?", current_user.id, id])
        raise VotingError.new("You have already voted for this post")
      end

      self.score += score
      transaction do
        execute_sql("UPDATE posts SET score = ? WHERE id = ?", self.score, id)
        votes.create(:user_id => current_user.id, :score => score)
      end
    end
  end
end
