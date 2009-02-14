class ModQueuePost < ActiveRecord::Base
  def self.reject_hidden(posts, user)
    hidden = ModQueuePost.find(:all, :conditions => "user_id = #{user.id}").map(&:post_id)
    h, v = posts.partition {|x| hidden.include?(x.id)}
    v + h
  end
  
  def self.prune!
    find(:all, :joins => "JOIN posts ON posts.id = mod_queue_posts.post_id", :conditions => "posts.status NOT IN ('pending', 'flagged')", :select => "mod_queue_posts.*").each do |mqp|
      mqp.destroy
    end
  end
end
