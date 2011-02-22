class Dmail < ActiveRecord::Base
  validates_presence_of :to_id
  validates_presence_of :from_id
  validates_format_of :title, :with => /\S/
  validates_format_of :body, :with => /\S/
  validate :validate_user_is_not_restricted
  
  belongs_to :to, :class_name => "User", :foreign_key => "to_id"
  belongs_to :from, :class_name => "User", :foreign_key => "from_id"
  
  after_create :update_recipient
  after_create :send_dmail
  
  named_scope :recent, lambda {{:conditions => ["created_at > ?", 1.day.ago]}}
  
  def validate_user_is_not_restricted
    if from.is_blocked? && from.dmails.recent.count == 3
      errors.add_to_base("Banned users cannot send more than three messages in a day")
      return false
    else
      return true
    end
  end
  
  def send_dmail
    if to.receive_dmails? && to.email.include?("@")
      UserMailer.deliver_dmail(to, from, title, body)
    end    
  end
  
  def mark_as_read!(current_user)
    update_attribute(:has_seen, true)
    
    unless Dmail.exists?(["to_id = ? AND has_seen = false", current_user.id])
      current_user.update_attribute(:has_mail, false)
    end
  end
  
  def update_recipient
    to.update_attribute(:has_mail, true)
  end
  
  def to_name
    User.find_name(to_id).tr("_", " ")
  end
  
  def from_name
    User.find_name(from_id).tr("_", " ")
  end
  
  def to_name=(name)
    user = User.find_by_name(name)
    return if user.nil?
    self.to_id = user.id
  end
  
  def from_name=(name)
    user = User.find_by_name(name)
    return if user.nil?
    self.from_id = user.id
  end
  
  def title
    if parent_id
      return "Re: " + self[:title]
    else
      return self[:title]
    end
  end
  
  def self.generate_sql(params, current_user)
    b = Nagato::Builder.new do |builder, cond|
      cond.add "(from_id = ? OR to_id = ?)", current_user.id, current_user.id
      
      if params[:from_name]
        user = User.find_by_name(params[:from_name])
        if user
          cond.add "from_id = ?", user.id
        end
      end

      if params[:to_name]
        user = User.find_by_name(params[:to_name])
        if user
          cond.add "to_id = ?", user.id
        end
      end
      
      if params[:title]
        cond.add "title ilike ?", "%#{params[:title]}%"
      end
    end

    return b.to_hash
  end
end
