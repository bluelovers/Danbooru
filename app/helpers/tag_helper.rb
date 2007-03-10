# test
module TagHelper
	def tag_link(t, prefix = "")
		html = ""

		begin
			case t
			when String
			name = t
			count = Tag.find_by_name(name).post_count

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

		tag_join = @params['tags'] ? '%20' : ''
		html << link_to("?", :controller => "wiki", :action => "view", :title => name) << " "
		html << link_to("+", :controller => "post", :action => "list", :tags => name + " " + @params["tags"].to_s) << " "
		html << link_to("&ndash;", :controller => "post", :action => "list", :tags => "-" + name + " " + @params["tags"].to_s) << " "
		html << link_to(name.tr("_", " "), :controller => "post", :action => "list", :tags => name) << " "

		case Tag.type(name)
		when Tag::TYPE_ARTIST
			html << '<span class="artist-tag">(artist)</span> '

		when Tag::TYPE_CHARACTER
			html << '<span class="character-tag">(character)</span> '

		when Tag::TYPE_COPYRIGHT
			html << '<span class="copyright-tag">(copyright)</span> '
		end

		html << content_tag("span", count.to_s, :class => "post-count")

		return html
	end

	def cloud_view(tags)
		html = ""

		tags.each do |tag|
			size = Math.log(tag.post_count) / 6
			html << link_to(tag.name.tr("_", " "), {:controller => "post", :action => "list", :tags => tag.name}, :style => "font-size:#{size}em", :title => "#{tag.post_count} posts") << " "
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
			Tag.find(:all, :conditions => ["name IN (?)", Tag.to_aliased(related)]).each {|i| all += i.related.map {|j| j[0]}}
		end
		all.join(" ")
	end
end
