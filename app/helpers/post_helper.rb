module PostHelper
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
    image_title = h(post.cached_tags + " rating:#{post.pretty_rating} score:#{post.score} user:#{post.author}")
    link_onclick = options[:onclick]
    link_onclick = %{onclick="#{link_onclick}"} if link_onclick
    width, height = post.preview_dimensions

    image = %{<img src="#{post.preview_url}" alt="#{image_title}" class="#{image_class}" title="#{image_title}" #{image_id} width="#{width}" height="#{height}">}
    plid = %{<span class="plid">#pl http://#{h CONFIG["server_host"]}/post/show/#{post.id}</span>}
    link = %{<a href="/post/show/#{post.id}/#{u(post.tag_title)}" #{link_onclick}>#{image}#{plid}</a>}
    span = %{<span class="thumb" id="p#{post.id}">#{link}</span>}
    return span
  end
end
