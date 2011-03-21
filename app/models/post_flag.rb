class PostFlag < ActiveRecord::Base
  set_table_name "flagged_post_details"
  
  attr_accessor :note
  
  belongs_to :post
  belongs_to :user
  validates_uniqueness_of :post_id, :scope => :user_id
  before_validation :merge_note
  
  named_scope :old, lambda {{:conditions => ["flagged_post_details.created_at <= ?", 3.days.ago]}}
  named_scope :unresolved, :conditions => ["flagged_post_details.is_resolved = false"]
  named_scope :resolved, :conditions => ["flagged_post_details.is_resolved = true"]
  
  def merge_note
    if !note.blank?
      self.reason = "#{reason}: #{note}"
    end
  end
  
  def author
    return User.find_name(self.user_id)
  end
end
