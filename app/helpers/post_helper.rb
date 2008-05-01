module PostHelper
  EMPTY_STAR = "☆"
  FILLED_STAR = "★"
  
  def auto_discovery_link_tag_with_id(type = :rss, url_options = {}, tag_options = {})
    tag(
      "link",
      "rel"   => tag_options[:rel] || "alternate",
      "type"  => tag_options[:type] || "application/#{type}+xml",
      "title" => tag_options[:title] || type.to_s.upcase,
      "id"    => tag_options[:id],
      "href"  => url_options.is_a?(Hash) ? url_for(url_options.merge(:only_path => false)) : url_options
    )
  end
  
  def print_preview(post, options = {})
    unless CONFIG["can_see_post"].call(@current_user, post)
      return ""
    end

    image_class = "preview"
    image_class += " flagged" if post.is_flagged?
    image_class += " pending" if post.is_pending?
    image_class += " has-children" if post.has_children?
    image_class += " has-parent" if post.parent_id
    image_id = options[:image_id]
    image_id = %{id="#{h(image_id)}"} if image_id
    image_title = h(post.cached_tags)
    link_onclick = options[:onclick]
    link_onclick = %{onclick="#{link_onclick}"} if link_onclick
    width, height = post.preview_dimensions

    image = %{<img src="#{post.preview_url}" alt="#{image_title}" class="#{image_class}" title="#{image_title}" #{image_id} width="#{width}" height="#{height}">}
    plid = %{<span class="plid">#pl http://#{h CONFIG["server_host"]}/post/show/#{post.id}</span>}
    link = %{<a href="/post/show/#{post.id}/#{u(post.tag_title)}" #{link_onclick}>#{image}#{plid}</a>}
    span = %{<span class="thumb" id="p#{post.id}">#{link}</span>}
    return span
  end

  def link_to_amb_tags(tags)
    html = "The following tags are potentially ambiguous: "
    tags = tags.map do |t|
      %{<a href="/post/index?tags=%2A#{u(t)}%2A">#{h(t)}</a>}
    end
    html + tags.join(", ")
  end
  
  def vote_widget(post, user, options = {})
    html = []
    
    html << %{<span class="stars" id="stars-#{post.id}">}
    
    if user.is_anonymous?
      current_user_vote = -100
    else
      current_user_vote = PostVotes.find_by_ids(user.id, post.id).score rescue -100
    end
    
    (CONFIG["vote_sum_min"]..CONFIG["vote_sum_max"]).each do |vote|
      if current_user_vote >= vote
        star = FILLED_STAR
      else
        star = EMPTY_STAR
      end
      
      desc = CONFIG["vote_descriptions"][vote]
      html << link_to_function(star, "Post.vote(#{post.id}, #{vote})", :class => "star-#{post.id}", :id => "star-#{vote}-#{post.id}", :onmouseover => "Post.vote_mouse_over('#{desc}', #{post.id}, #{vote})", :onmouseout => "Post.vote_mouse_out('#{desc}', #{post.id}, #{vote})")
    end
    
    html << " "
    html << %{<span class="vote-desc" id="vote-desc-#{post.id}"></span>}
    html << %{</span>}
    return html
  end
end
