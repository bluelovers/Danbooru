class PostFlag < ActiveRecord::Base
  set_table_name "flagged_post_details"
  
  belongs_to :post
  belongs_to :user
  validates_uniqueness_of :post_id, :scope => :user_id
  
  def author
    return User.find_name(self.user_id)
  end
end
