class ModQueuePost < ActiveRecord::Base
  def self.reject_hidden(posts, user, hidden_only = false)
    hidden = ModQueuePost.find(:all, :conditions => "user_id = #{user.id}").map(&:post_id)
    if hidden_only
      posts.select {|x| hidden.include?(x.id)}
    else
      posts.reject {|x| hidden.include?(x.id)}
    end
  end
  
  def self.prune!
    find(:all, :joins => "JOIN posts ON posts.id = mod_queue_posts.post_id", :conditions => "posts.status NOT IN ('pending', 'flagged')", :select => "mod_queue_posts.*").each do |mqp|
      mqp.destroy
    end
  end
end
