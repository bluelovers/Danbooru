module PostHelper
	def link_to_amb_tags(tags)
		html = "The following tags are potentially ambiguous: "
		tags = tags.map do |t|
			link_to(t, :controller => "wiki", :action => "show", :title => t)
		end
		html + tags.join(", ")
	end
end
