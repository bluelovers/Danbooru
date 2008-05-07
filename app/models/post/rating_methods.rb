module PostRatingMethods
  attr_accessor :old_rating
  
  def rating=(r)
    if r == nil && !new_record?
      return
    end

    if is_rating_locked?
      return
    end

    r = r.to_s.downcase[0, 1]

    if %w(q e s).include?(r)
      new_rating = r
    else
      new_rating = 'q'
    end

    return if rating == new_rating
    self.old_rating = rating
    write_attribute(:rating, new_rating)
    touch_change_seq!
  end
  
  def pretty_rating
    case rating
    when "q"
      return "Questionable"

    when "e"
      return "Explicit"

    when "s"
      return "Safe"
    end
  end
end
