class FlaggedPostDetail < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  
  def author
    return User.find_name(self.user_id)
  end
end
