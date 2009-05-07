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

    link_onclick = options[:onclick]
    link_onclick = %{onclick="#{link_onclick}"} if link_onclick
    width, height = post.preview_dimensions
    image_id = options[:image_id]
    image_id = %{id="#{h(image_id)}"} if image_id
    title = "#{h(post.cached_tags)} rating:#{post.pretty_rating} score:#{post.score} user:#{h(post.author)}"
    
    %{
      <span class="thumb" id="p#{post.id}">
        <a href="/post/show/#{post.id}/#{u(post.tag_title)}" #{link_onclick}>
          <img #{image_id} class="preview #{'flagged' if post.is_flagged?} #{'pending' if post.is_pending?} #{'has-children' if post.has_children?} #{'has-parent' if post.parent_id}" src="#{post.preview_url}" title="#{title}" alt="#{title}" width=#{width} height=#{height}>
        </a>
      </span>
    }
  end
  
  def print_tag_sidebar_helper(tag)
    # tag = [name, count, type]
    
    if tag.is_a?(String)
      tag_name = tag
      tag_type, tag_count = Tag.type_and_count(tag)
      type_name = Tag.type_name_from_value(tag_type)
    else
      tag_name = tag[0]
      tag_count = tag[1]
      type_name = Tag.type_name_from_value(tag[2])
    end
    
    html = %{<li class="tag-type-#{type_name}">}

    if type_name == "artist"
      html << %{<a href="/artist/show?name=#{u(tag_name)}">?</a> }
    else
      html << %{<a href="/wiki/show?title=#{u(tag_name)}">?</a> }
    end

    if @current_user.is_privileged_or_higher?
      html << %{<a href="/post/index?tags=#{u(tag_name)}+#{u(params[:tags])}">+</a> }
      html << %{<a href="/post/index?tags=-#{u(tag_name)}+#{u(params[:tags])}">&ndash;</a> }
    end

    html << %{<a href="/post/index?tags=#{u(tag_name)}">#{h(tag_name.tr("_", " "))}</a> }
    html << %{<span class="post-count">#{tag_count}</span> }
    html << '</li>'
    return html
  end
  
  def print_tag_sidebar(query)
    if query.is_a?(Post)
      tags = {:include => query.cached_tags.split(/ /)}
    elsif !query.blank?
      tags = Tag.parse_query(query)
    else
      tags = {:include => Tag.trending}
    end
    
    html = ['<div style="margin-bottom: 1em;">', '<h5>Tags</h5>', '<ul id="tag-sidebar">']

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
      Tag.find_related(tags[:related]).each do |tag|
        html << print_tag_sidebar_helper(tag)
      end
    end

    html += ['</ul>', '</div>']

    if !query.is_a?(Post) && @current_user.is_privileged_or_higher?
      if tags[:subscriptions].is_a?(String)
        html += ['<div style="margin-bottom: 1em;">', '<h5>Subscribed Tags</h5>', '<ul id="tag-subs-sidebar">']
        subs = TagSubscription.find_tags(tags[:subscriptions])
        subs.each do |sub|
          html << print_tag_sidebar_helper(sub)
        end
        html += ['</ul>', '</div>']
      end
      
      deleted_count = Post.fast_deleted_count(query)
      if deleted_count > 0
        html += ['<div style="margin-bottom: 1em;">', '<h5>Tag Statistics</h5>', '<ul id="tag-stats-sidebar">']
        html << %{<li><a href="/post/index?tags=#{u(query)}+status%3Adeleted">deleted:#{deleted_count}</a></li>}
        html += ['</ul>', '</div>']        
      end
    end
    
    html.join("\n")
  end
end
