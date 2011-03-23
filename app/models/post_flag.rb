class PostFlag < ActiveRecord::Base
  set_table_name "flagged_post_details"
  
  belongs_to :post
  belongs_to :user
  validates_uniqueness_of :post_id, :scope => :user_id
  validates_presence_of :reason
  
  named_scope :old, lambda {{:conditions => ["flagged_post_details.created_at <= ?", 3.days.ago]}}
  named_scope :unresolved, :conditions => ["flagged_post_details.is_resolved = false"]
  named_scope :resolved, :conditions => ["flagged_post_details.is_resolved = true"]
  
  def author
    return User.find_name(self.user_id)
  end
end
