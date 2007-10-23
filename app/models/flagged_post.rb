class FlaggedPost < ActiveRecord::Base
  validates_uniqueness_of :post_id
  
  def self.flag(post_id, reason)
    create(:post_id => post_id, :reason => reason)
  end
  
  def self.unflag(post_id)
    destroy_all(["post_id = ?", post_id])
  end
end
