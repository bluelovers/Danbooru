module TagHelper
  def tag_links(tags, options = {})
    return "" if tags.blank?
    prefix = options[:prefix] || ""
    hide_unsafe_posts = options[:hide_unsafe_posts]
    count_field = hide_unsafe_posts ? "safe_post_count" : "post_count"        
    
    html = ""
    tags = tags.map do |t|
      case t
      when String
        tag = Tag.find(:first, :conditions => ["name = ?", t], :select => "name, #{count_field}")
        
        if tag
          [tag.name, tag.__send__(count_field)]
        else
          [t, 0]
        end

      when Hash
        [t["name"], t["post_count"]]

      when Tag
        [t.name, t.__send__(count_field)]
        
      when Array
        t

      else
        raise
      end
    end

    if @current_user
      type_map = Tag.find(:all, :conditions => ["name in (?)", tags.map {|x| x[0]}], :select => "name, tag_type").inject({}) do |h, rec| 
        h[rec.name] = case rec.tag_type
        when Tag.types[:artist]
          "artist"
          
        when Tag.types[:character]
          "character"
          
        when Tag.types[:copyright]
          "copyright"
          
        else
          nil
        end
        
        h
      end
    else
      type_map = {}
    end

    tags.each do |name, count|
      name = name || "UNKNOWN"
      
      if type_map[name]
        html << '<li class="tag-type-' + type_map[name] + '">'
      else
        html << '<li>'
      end
      
      html << link_to("?", :controller => "wiki", :action => "show", :title => name) << " "
      
      if @current_user
        html << link_to("+", :controller => "post", :action => "index", :tags => name + " " + params[:tags].to_s) << " "
        html << link_to("&ndash;", :controller => "post", :action => "index", :tags => "-" + name + " " + params[:tags].to_s) << " "
      end

      html << link_to(h(name.tr("_", " ")), :controller => "post", :action => "index", :tags => name) << " "
      html << content_tag("span", count.to_i, :class => "post-count") << " "
      html << '</li>'
    end

    return html
  end

  def cloud_view(tags, divisor = 6)
    html = ""

    tags.sort {|a, b| a["name"] <=> b["name"]}.each do |tag|
      size = Math.log(tag["post_count"].to_i) / divisor
      size = 0.8 if size < 0.8
      html << link_to(h(tag["name"].tr("_", " ")), {:controller => "post", :action => "index", :tags => tag["name"]}, :style => "font-size:#{size}em", :title => "#{tag['post_count']} posts") << " "
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
