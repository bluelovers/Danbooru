class Dmail < ActiveRecord::Base
  validates_presence_of :to_id
  validates_presence_of :from_id
  validates_format_of :title, :with => /\S/
  validates_format_of :body, :with => /\S/

  belongs_to :to, :class_name => "User", :foreign_key => "to_id"
  belongs_to :from, :class_name => "User", :foreign_key => "from_id"
  
  after_save :update_recipient
  
  def update_recipient
    to.update_attribute(:has_mail, true)
  end
  
  def to_name
    User.find_name(to_id)
  end
  
  def from_name
    User.find_name(from_id)
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
end
