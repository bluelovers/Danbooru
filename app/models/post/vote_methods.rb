module PostVoteMethods
  class InvalidScoreError < Exception
  end
  
  class AlreadyVotedError < Exception
  end
  
  def vote!(current_user, score, ip_addr)
    unless [1, -1].include?(score)
      raise InvalidScoreError.new
    end
    
    if current_user.is_mod_or_higher? && score < 0
      score *= 5
    end
    
    if last_voter_ip == ip_addr
      raise AlreadyVotedError.new
    end
    
    if CONFIG["enable_caching"] && RAILS_ENV != "test" && Cache.get("vote:#{ip_addr}:#{id}")
      raise AlreadyVotedError.new
    end

    self.score += score
    execute_sql("UPDATE posts SET score = ?, last_voter_ip = ? WHERE id = ?", self.score, ip_addr, id)
    
    if CONFIG["enable_caching"] && RAILS_ENV != "test"
      Cache.put("vote:#{ip_addr}:#{id}", 1)
    end
  end
end
