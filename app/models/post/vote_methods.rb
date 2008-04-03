module PostMethods
  module VoteMethods
    def vote!(score, ip_addr)
      if last_voter_ip == ip_addr
        return false
      else
        self.score += score
        execute_sql("UPDATE posts SET score = ?, last_voter_ip = ? WHERE id = ?", score, ip_addr, id)
        return true
      end
    end
  end
end