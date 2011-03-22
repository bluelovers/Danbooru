class PostAppeal < ActiveRecord::Base
  attr_accessor :note
  validates_uniqueness_of :post_id, :scope => :user_id
  before_validation :merge_note
  validate :appealer_is_not_limited
  belongs_to :user
  belongs_to :post
  
  def appealer_is_not_limited
    if PostAppeal.count(:conditions => ["user_id = ? and created_at >= ?", user_id, 1.day.ago]) >= 5
      errors.add(:user, "can only appeal 5 posts a day")
      return false
    else
      return true
    end
  end
  
  def merge_note
    if !note.blank?
      self.reason = "#{reason}: #{note}"
    end
  end
end
