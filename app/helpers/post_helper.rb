module PostHelper
  def wiki_excerpt(artist, wiki_page, split_tags)
    html = ""
    
    if artist || wiki_page || split_tags.size == 1
      html << '<div>'
      
      if artist
        html << %{<h5><a href="/artist/show/#{artist.id}">#{h(split_tags.to_s)}</a></h5>}
        html << '<p>' + DText.parse(artist.notes, :inline => true) + '</p>'
      elsif split_tags.size == 1
        html << %{<h5><a href="/wiki/show?title=#{h(split_tags.to_s)}">#{h(split_tags.to_s)}</a></h5>}
        
        if wiki_page
          html << '<p>' + DText.parse(wiki_page.body, :inline => true) + '</p>'
        else
          html << '<p>There is no wiki for this tag.</p>'
        end
      end
      
      html << '</div>'
    end
    
    html
  end
  
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
  
  def print_tag_sidebar_helper(tag)
    # tag = [name, count, type]
    
    if tag.is_a?(String)
      tag_name = tag
      tag_type, tag_count = Tag.type_and_count(tag)
      type_name = Tag.type_name_from_value(tag_type.to_i)
    else
      tag_name = tag[0]
      tag_count = tag[1]
      type_name = Tag.type_name_from_value(tag[2].to_i)
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
