class FlaggedPost < ActiveRecord::Base
  def self.flag(post_id, reason)
    create(:post_id => post_id, :reason => reason)
  end
  
  def self.unflag(post_id)
    destroy_all(["post_id = ?", post_id])
  end  
end
