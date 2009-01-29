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
  
  def print_tag_sidebar_helper(tag)
    if tag.is_a?(String)
      tag = TagProxy.new(tag)
    end
    
    html = %{<li class="tag-type-#{tag.tag_type}">}

    if CONFIG["enable_artists"] && tag.tag_type == "artist"
      html << %{<a href="/artist/show?name=#{u(tag.name)}">?</a> }
    else
      html << %{<a href="/wiki/show?title=#{u(tag.name)}">?</a> }
    end

    if @current_user.is_privileged_or_higher?
      html << %{<a href="/post/index?tags=#{u(tag.name)}+#{u(params[:tags])}">+</a> }
      html << %{<a href="/post/index?tags=-#{u(tag.name)}+#{u(params[:tags])}">&ndash;</a> }
    end

    html << %{<a href="/post/index?tags=#{u(tag.name)}">#{h(tag.name.tr("_", " "))}</a> }
    html << %{<span class="post-count">#{tag.post_count}</span> }
    html << '</li>'
    return html
  end
  
  def print_tag_sidebar(query)
    if query.is_a?(Post)
      cache_key = "tag_sidebar:post_id:#{query.id}"
    else
      cache_key = "tag_sidebar:" + @current_user.is_privileged_or_higher?.to_s + ":" + Digest::MD5.hexdigest(query.to_s)
    end

    Cache.get(cache_key, 4.hours) do
      if query.is_a?(Post)
        tags = {:include => query.cached_tags.split(/ /)}
      elsif !query.blank?
        tags = Tag.parse_query(query)
      else
        tags = {:include => Tag.count_by_period(1.day.ago, Time.now, :limit => 25)}
      end
      
      html = ['<div>', '<h5>Tags</h5>', '<ul id="tag-sidebar">']

      if tags[:exclude]
        tags[:exclude].each do |tag|
          html << print_tag_sidebar_helper(tag)
        end
      end

      if tags[:include]
        tags[:include].each do |tag|
          html << print_tag_sidebar_helper(tag)
        end
      end
      
      if tags[:related]
        Tag.find_related(tags[:related]).map {|x| TagProxy.new(x[0], x[1])}.each do |tag|
          html << print_tag_sidebar_helper(tag)
        end
      end

      html += ['</ul>', '</div>']
      html.join("\n")
    end
  end
end
