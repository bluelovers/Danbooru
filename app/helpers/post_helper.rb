module PostHelper
  def print_preview(post, options = {})
    if hide_explicit? && post.rating == "e"
      return ""
    end
    
    image_class = "preview"
    image_class += " pending" if post.is_pending?
    image_class += " flagged" if post.is_flagged?
    image_class += " has-children" if post.has_children?
    image_id = options[:image_id]
    image_id = %{id="#{h(image_id)}"} if image_id
    link_onclick = options[:onclick]
    link_onclick = %{onclick="#{link_onclick}"} if link_onclick

    image = %{<img src="#{post.preview_url}" alt="#{h(post.cached_tags)}" class="#{image_class}" title="#{h(post.cached_tags)}" #{image_id}/>}
    link = %{<a href="/post/show/#{post.id}/#{h(post.tag_title)}" #{link_onclick}>#{image}</a>}
    span = %{<span class="thumb" id="p#{post.id}">#{link}</span>}
    return span
  end

  def link_to_amb_tags(tags)
    html = "The following tags are potentially ambiguous: "
    tags = tags.map do |t|
      %{<a href="/post/index?tags=%2A#{h(t)}%2A">#{h(t)}</a>}
    end
    html + tags.join(", ")
  end
end
