class UserRecord < ActiveRecord::Base
  belongs_to :user
  belongs_to :reporter, :foreign_key => "reported_by", :class_name => "User"
  validates_presence_of :user_id
  validates_presence_of :reported_by
  after_save :generate_dmail
  named_scope :for_user, lambda {|user_id| {:conditions => ["user_id = ?", user_id]}}
  named_scope :negative, :conditions => ["score < 0"]
  named_scope :positive, :conditions => ["score > 0"]
  named_scope :neutral, :conditions => ["score = 0"]
  
  def user=(name)
    self.user_id = User.find_by_name(name).id rescue nil
  end
  
  def score_text
    case score
    when 1
      "positive"
      
    when 0
      "neutral"
      
    when -1
      "negative"
    end
  end
  
  def generate_dmail
    body = %{#{reporter.name} created a "#{score_text} record":/user_record/index?user_id=#{user_id} for your account.}
    
    Dmail.create(:from_id => reported_by, :to_id => user_id, :title => "Your user record has been updated", :body => body)
  end
end
