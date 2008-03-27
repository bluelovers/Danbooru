module PostMethods
  module VoteMethods
    def vote!(score, ip_addr)
      if self.last_voter_ip == ip_addr
        return false
      else
        self.score += score
        connection.execute("UPDATE posts SET score = #{self.score}, last_voter_ip = '#{ip_addr}' WHERE id = #{self.id}")
      end

      return true
    end
  end
end