class Dmail < ActiveRecord::Base
  validates_presence_of :to_id
  validates_presence_of :from_id
  validates_format_of :title, :with => /\S/
  validates_format_of :body, :with => /\S/

  belongs_to :to, :class_name => "User", :foreign_key => "to_id"
  belongs_to :from, :class_name => "User", :foreign_key => "from_id"
  
  alias_method :original_to=, :to=
  
  def to=(name)
    if name.is_a?(String)
      user = User.find_by_name(name)
      self.original_to = user if user
    else
      self.original_to = name
    end
  end
end
