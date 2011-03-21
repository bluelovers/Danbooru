module PostHelper
  def will_paginate_for_posts(posts)
    page = params[:page].to_i
    if page >= 1_000 || params[:before_id]
      post_pagination_links(posts)
    else
      will_paginate(posts)
    end
  end
  
  def post_pagination_links(posts)
    html = ""
    
    previous_link = request.env["HTTP_REFERER"]
    html << %[<a href="#{previous_link}">&laquo; Previous</a>]
    
    if posts.any?
      next_link = url_for(:controller => "post", :action => "index", :tags => params[:tags], :before_id => posts[-1].id, :page => nil)
      html << %[<a href="#{next_link}">Next &raquo;</a>]
    end
  end
  
  def post_flag_reason_select_tag(name)
    select_tag(name, options_for_select(["Not anime related", "Furry", "Watermarked", "Poor compression", "Mutilation", "Distension" ,"Scat", "Absurd proportions", "Other", "Duplicate", "Banned artist", "Poorly drawn", "Fake translation", "Nude filter"].sort))
  end
  
  def post_appeal_reason_select_tag(name)
    select_tag(name, options_for_select(["Artistic merit", "Funny", "Weird", "Translated", "Other"].sort))
  end
  
  def post_flag_summary(post)
    post.flags.map do |flag|
      '<span class="flag-and-reason-count">' + h(flag.reason) + '</span>'
    end.join("; ")
  end
  
  def post_appeal_summary(post)
    post.appeals.map do |appeal|
      '<span class="flag-and-reason-count">' + h(appeal.reason) + '</span>'
    end.join("; ")
  end
  
  def wiki_excerpt(artist, wiki_page, split_tags)
    html = ""
    
    if artist || wiki_page || split_tags.size == 1
      if artist
        url = %{/artist/show/#{artist.id}}
        html << '<p>' + DText.parse(artist.notes, :inline => true) + '</p>'
      elsif split_tags.size == 1
        url = %{/wiki/show?title=#{h(split_tags.to_s)}}
        
        if wiki_page
          html << '<p>' + DText.parse(wiki_page.body, :inline => true) + '</p>'
        else
          html << '<p>There is no wiki for this tag.</p>'
        end
      end

      html << %{<p><a href="#{url}">Full entry &raquo;</a></p>}
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
    if tag.is_a?(String)
      tag_name = tag
      type_value, post_count = Tag.type_and_count(tag_name)
      type_name = Tag.type_name_from_value(type_value)
    else
      tag_name = tag[0]
      type_name, post_count = Tag.type_name(tag[0]), tag[1]
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
    html << %{<span class="post-count">#{post_count}</span>}
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
    
    html = ['<div style="margin-bottom: 1em;">', '<ul id="tag-sidebar">']

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
