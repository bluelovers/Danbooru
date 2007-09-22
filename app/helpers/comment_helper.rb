module CommentHelper
	def print_comment(c)
		text = format_text(c.body)
		text = text.gsub(/&gt;&gt;(\d+)/) do
		  id = $1
			content_tag("div", link_to("&gt;&gt;#{id}", {:controller => "comment", :action => "show", :id => id}, :onclick => "this.parentNode.innerHTML = $('cbody#{id}').innerHTML; return false"), :class => "comment-quote")
		end
		text = text.gsub(/&lt;(?:s|spoilers|spoiler)&gt;(.+?)&lt;\/(?:s|spoilers|spoiler)&gt;/, '<a href="#" class="spoilers">\1</a>')
		return text
	end
end
