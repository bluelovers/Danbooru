module PostHelper
  def print_preview(post, options = {})
    if post.blacklisted?(options[:user])
      return ""
    end

		if hide_unsafe_posts? && post.rating != "s"
			return ""
		end

    image = image_tag(post.preview_url, :alt => post.cached_tags, :class => "preview", :title => post.cached_tags, :id => options[:image_id])
    link = link_to(image, {:controller => "post", :action => "show", :id => post.id}, :onclick => options[:onclick])
    span = content_tag "span", link, :class => "thumb", :id => "p#{post.id}"
    return span
  end

	def link_to_amb_tags(tags)
		html = "The following tags are potentially ambiguous: "
		tags = tags.map do |t|
			link_to(t, :controller => "wiki", :action => "show", :title => t)
		end
		html + tags.join(", ")
	end
end
