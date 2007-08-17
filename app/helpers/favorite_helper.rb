module FavoriteHelper
	def favorite_list(post)
	  html = ""
	  users = post.favorited_by

	  if users.empty?
	    html << "no one"
	  else
	    html << users.map {|user| link_to(user.name, :controller => "favorite", :action => "show", :id => user.id)}.join(", ")
	  end

	  return html
	end
	
	def print_also_favorited_by(posts, user)
		post_ids = posts.map {|x| x.id}
		users = User.find(
			:all, 
			:joins => "JOIN favorites ON favorites.user_id = users.id", 
			:conditions => ["favorites.post_id IN (?) AND users.id <> ?", post_ids, user.id], 
			:order => "lower(name)", 
			:select => "users.*"
		)
		s = users.map {|x| link_to(x.name, :controller => "favorite", :action => "show", :id => x.id)}.uniq.to_sentence
		if s.empty?
			return "no one"
		else
			return s
		end
	end
end
