class Ban < ActiveRecord::Base
  def duration=(dur)
    case dur
    when "one_day"
      self.expires_at = 1.day.from_now
      
    when "one_week"
      self.expires_at = 1.week.from_now
      
    when "one_month"
      self.expires_at = 1.month.from_now
      
    when "one_year"
      self.expires_at = 1.year.from_now
      
    else
      raise "Unknown duration"
    end
  end
  
  def duration
  end
end
