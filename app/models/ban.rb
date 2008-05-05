class Ban < ActiveRecord::Base
  after_create :save_to_record
  after_create :update_level
  
  def update_level
    user = User.find(user_id)
    user.level = CONFIG["user_levels"]["Blocked"]
    user.save
  end
  
  def save_to_record
    UserRecord.create(:user_id => self.user_id, :reported_by => self.banned_by, :is_positive => false, :body => "Blocked: #{self.reason}")
  end
  
  def duration=(dur)
    self.expires_at = dur.to_i.days.from_now
    @duration = dur
  end
  
  def duration
    @duration
  end
end
