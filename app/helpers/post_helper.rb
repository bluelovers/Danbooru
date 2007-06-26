module PostHelper
  def favorite_list(post)
    html = ""
    users = User.find_people_who_favorited(post.id)

    if users.empty?
      html << "no one"
    else
      html << users.map {|user| link_to(user.name, :controller => "user", :action => "favorites", :id => user.id)}.join(", ")
    end

    return html
  end

	def link_to_amb_tags(tags)
		html = "The following tags are potentially ambiguous: "
		tags = tags.map do |t|
			link_to(t, :controller => "wiki", :action => "show", :title => t)
		end
		html + tags.join(", ")
	end
end
