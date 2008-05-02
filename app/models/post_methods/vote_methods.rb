module PostMethods
  module VoteMethods
    def vote!(score, ip_addr)
      if last_voter_ip == ip_addr
        return false
      elsif CONFIG["enable_caching"] && Cache.get("vote:#{ip_addr}:#{id}")
        return false
      else
        self.score += score
        execute_sql("UPDATE posts SET score = ?, last_voter_ip = ? WHERE id = ?", self.score, ip_addr, id)
        
        if CONFIG["enable_caching"]
          Cache.put("vote:#{ip_addr}:#{id}", 1)
        end
        
        return true
      end
    end
  end
end
