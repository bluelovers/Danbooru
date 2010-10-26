module PostTagHistoryHelper
  def tag_list(tags, options = {})
    return "" if tags.blank?
    prefix = options[:prefix] || ""
    obsolete = options[:obsolete] || []
    
    html = ""

    tags.sort.each do |name|
      name ||= "UNKNOWN"
      next if name == "parent:"
      
      tag_type = Tag.type_name(name)
      
      obsolete_tag = ([name] & obsolete).empty? ?  "" : " obsolete-tag-change"
      html << %{<span class="tag-type-#{tag_type}#{obsolete_tag}">}
      
      html << %{#{prefix}<a href="/post/index?tags=#{u(name)}">#{h(name)}</a> }
      html << '</span>'
    end

    return html
  end

  def tag_history_pagination_links(changes)
    html = ""
    
    previous_link = request.env["HTTP_REFERER"]
    html << %[<a href="#{previous_link}">&laquo; Previous</a>]
    
    if changes.any?
      next_link = url_for(:controller => "post_tag_history", :action => "index", :tags => params[:tags], :before_id => changes[-1].id, :user_name => params[:user_name], :post_id => params[:post_id], :user_id => params[:user_id], :page => nil)
      html << %[<a href="#{next_link}">Next &raquo;</a>]
    end
  end
end
