module PoolHelper
	def pool_list(post)
		html = ""
		pools = Pool.find(:all, :joins => "JOIN pools_posts ON pools_posts.pool_id = pools.id", :conditions => "pools_posts.post_id = #{post.id}", :order => "pools.name", :select => "pools.*")
		
		if pools.empty?
			html << "none"
		else
			html << pools.map {|p| link_to(p.name, :controller => "pool", :action => "show", :id => p.id)}.join(", ")
		end
		
		return html
	end
end
