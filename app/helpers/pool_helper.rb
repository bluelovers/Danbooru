module PoolHelper
  def pool_update_diff(updates, i)
    current = updates[i]
    previous = nil

    while i < updates.size
      previous = updates[i + 1]
      break if previous && previous.pool_id == current.pool_id
      i += 1
    end
    
    if previous.nil?
      previous = PoolUpdate.find(:first, :order => "id desc", :conditions => ["pool_id = ? AND id < ?", current.pool_id, current.id])
      return "" if previous.nil?
    end
    
    current_ids = current.post_ids_only
    previous_ids = previous.post_ids_only
    added = current_ids - previous_ids
    removed = previous_ids - current_ids
    
    added.map {|x| "<ins>+<a target=\"blank\" href=\"/post/show/#{x}\">#{x}</a></ins>"}.join(" ") + " " + removed.map {|x| "<del>-<a target=\"blank\" href=\"/post/show/#{x}\">#{x}</a></del>"}.join(" ")
  end
  
  def pool_list(post)
    html = ""
    pools = Pool.find(:all, :joins => "JOIN pools_posts ON pools_posts.pool_id = pools.id", :conditions => "pools_posts.post_id = #{post.id}", :order => "pools.name", :select => "pools.name, pools.id")
    
    if pools.empty?
      html << "none"
    else
      html << pools.map {|p| link_to(h(p.pretty_name), :controller => "pool", :action => "show", :id => p.id)}.join(", ")
    end
    
    return html
  end
end
