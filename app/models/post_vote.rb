class PostVote < ActiveRecord::Base
  belongs_to :post
  
  def self.prune!
    destroy_all(["created_at < ?", 14.days.ago])
  end
end
