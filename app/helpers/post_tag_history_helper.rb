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
end
