module TagHelper
	def tag_link(t, prefix = "")
		html = ""

		begin
			case t
			when String
        name = t
        count = Tag.find_by_name(name).post_count

      when Hash
        name = t["name"]
        count = t["post_count"]

			when Tag
        name = t.name
        count = t.post_count
        
			when Array
        name = t[0].to_s
        count = t[1]

			else
        raise

			end
		rescue Exception
			return ""
		end

		html << link_to("?", :controller => "wiki", :action => "show", :title => name) << " "

		if @current_user || CONFIG["enable_anonymous_post_access"] == false
			html << link_to("+", :controller => "post", :action => "index", :tags => name + " " + params[:tags].to_s) << " "
			html << link_to("&ndash;", :controller => "post", :action => "index", :tags => "-" + name + " " + params[:tags].to_s) << " "
		end

		html << link_to(name.tr("_", " "), :controller => "post", :action => "index", :tags => name) << " "

		if CONFIG["enable_tag_type_lookups"] && (@current_user || CONFIG["enable_anonymous_post_access"] == false)
			tag_type = Tag.find(:first, :conditions => ["name = ?", name], :select => "tag_type")
			tag_type = tag_type.tag_type if tag_type

			case tag_type
			when Tag.types[:artist]
				html << '<span class="artist-tag">(artist)</span> '

			when Tag.types[:character]
				html << '<span class="character-tag">(character)</span> '

			when Tag.types[:copyright]
				html << '<span class="copyright-tag">(copyright)</span> '
			end
		end

		html << content_tag("span", count.to_s, :class => "post-count")

		return html
	end

	def cloud_view(tags, divisor = 6)
		html = ""

		tags.sort {|a, b| a["name"] <=> b["name"]}.each do |tag|
			size = Math.log(tag["post_count"].to_i) / divisor
			size = 0.8 if size < 0.8
			html << link_to(tag["name"].tr("_", " "), {:controller => "post", :action => "index", :tags => tag["name"]}, :style => "font-size:#{size}em", :title => "#{tag['post_count']} posts") << " "
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
