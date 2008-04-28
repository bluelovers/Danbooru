module PostMethods
  module VoteMethods
    def recalculate_score!()
      votes = connection.select_value("SELECT sum(GREATEST(#{CONFIG["vote_sum_min"]}, LEAST(#{CONFIG["vote_sum_max"]}, score))) FROM post_votes WHERE post_id = #{self.id}").to_i
      votes += self.anonymous_votes
      self.score = votes
    end

    def vote!(score, user, ip_addr, options={})
      if user.is_anonymous? || options.fetch(:anonymous, false)
        if last_voter_ip == ip_addr
          return false
        end

        self.anonymous_votes += score
      else
        vote = PostVotes.find_by_ids(user.id, self.id)

        if last_voter_ip == ip_addr and not vote
          # The user voted anonymously, then logged in and tried to vote again.  A user
          # may be browsing anonymously, decide to make an account, then once he has access
          # to full voting, decide to set his permanent vote.  Just undo the anonymous vote.
          self.anonymous_votes -= self.last_vote
        end

        if not vote
          vote = PostVotes.find_or_create_by_id(user.id, self.id)
        end

        vote.update_attributes(:score => score, :updated_at => Time.now)
      end

      self.last_voter_ip = ip_addr
      self.last_vote = score
      self.recalculate_score!

      return true
    end
  end
end
