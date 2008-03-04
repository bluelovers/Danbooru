module TagHelper
  def tag_links(tags, options = {})
    return "" if tags.blank?
    prefix = options[:prefix] || ""
    
    html = ""
    
    case tags[0]
    when String
      tags = Tag.find(:all, :conditions => ["name in (?)", tags], :select => "name, post_count").inject({}) {|all, x| all[x.name] = x.post_count; all}.to_a.sort {|a, b| a[0] <=> b[0]}

    when Hash
      tags = tags.map {|x| [x["name"], x["post_count"]]}
      
    when Tag
      tags = tags.map {|x| [x.name, x.post_count]}
    end

    tags.each do |name, count|
      name = name || "UNKNOWN"
      
      html << '<li class="tag-type-' + Tag.find_type(name) + '">'
      html << %{<a href="/wiki/show?title=#{u(name)}">?</a> }
      
      if @current_user.is_privileged_or_higher?
        html << %{<a href="/post/index?tags=#{u(name)}+#{u(params[:tags])}">+</a> }
        html << %{<a href="/post/index?tags=-#{u(name)}+#{u(params[:tags])}">&ndash;</a> }
      end

      html << %{<a href="/post/index?tags=#{u(name)}">#{h(name.tr("_", " "))}</a> }
      html << %{<span class="post-count">#{count}</span> }
      html << '</li>'
    end

    return html
  end

  def cloud_view(tags, divisor = 6)
    html = ""

    tags.sort {|a, b| a["name"] <=> b["name"]}.each do |tag|
      size = Math.log(tag["post_count"].to_i) / divisor
      size = 0.8 if size < 0.8
      html << %{<a href="/post/index?tags=#{u(tag["name"])}" style="font-size: #{size}em;" title="#{tag["post_count"]} posts">#{h(tag["name"])}</a> }
    end

    return html
  end

  def related_tags(tags)
    if tags.blank?
      return ""
    end

    all = []
    pattern, related = tags.split(/\s+/).partition {|i| i.include?("*")}
    pattern.each {|i| all += Tag.find(:all, :conditions => ["name LIKE ?", i.tr("*", "%")]).map {|j| j.name}}
    if related.any?
      Tag.find(:all, :conditions => ["name IN (?)", TagAlias.to_aliased(related)]).each {|i| all += i.related.map {|j| j[0]}}
    end
    all.join(" ")
  end
end
