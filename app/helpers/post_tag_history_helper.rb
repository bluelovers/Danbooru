module PostTagHistoryHelper
  def tag_list(tags, options = {})
    return "" if tags.blank?
    prefix = options[:prefix] || ""
    
    html = ""
    
    tags = Tag.find(:all, :conditions => ["name in (?)", tags], :select => "name").inject([]) {|all, x| all << x.name; all}.to_a.sort {|a, b| a <=> b}

    tags.each do |name|
      name ||= "UNKNOWN"
      
      tag_type = Tag.type_name(name)
      
      html << %{<span class="tag-type-#{tag_type}">}
      
      html << %{#{prefix}<a href="/post/index?tags=#{u(name)}">#{h(name)}</a> }
      html << '</span>'
    end

    return html
  end
end
