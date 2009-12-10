class CommentVote < ActiveRecord::Base
  def self.prune!
    destroy_all(["created_at < ?", 14.days.ago])
  end
end
