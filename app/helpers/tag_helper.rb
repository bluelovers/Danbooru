module TagHelper
  def cloud_view(tags, divisor = 6)
    html = ""

    tags.sort {|a, b| a.to_s <=> b.to_s}.each do |tag|
      size = Math.log(tag.post_count) / divisor
      size = 0.8 if size < 0.8
      html << %{<a href="/post/index?tags=#{u(tag.name)}" style="font-size: #{size}em;" title="#{tag.post_count} posts">#{h(tag.name)}</a> }
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
