class Ban < ActiveRecord::Base
  before_create :save_level
  after_create :save_to_record
  after_create :update_level
  after_create :create_mod_action
  after_destroy :restore_level
  belongs_to :user
  
  def create_mod_action
    ModAction.create(:description => "banned #{user.name}", :user_id => banned_by)
  end
  
  def restore_level
    User.find(user_id).update_attribute(:level, old_level)
  end
  
  def save_level
    self.old_level = User.find(user_id).level
  end
  
  def update_level
    user = User.find(user_id)
    user.level = CONFIG["user_levels"]["Blocked"]
    user.save
  end
  
  def save_to_record
    UserRecord.create(:user_id => self.user_id, :reported_by => self.banned_by, :score => -1, :body => "Blocked: #{self.reason}")
  end
  
  def duration=(dur)
    self.expires_at = dur.to_i.days.from_now
    @duration = dur
  end
  
  def duration
    @duration
  end
end
