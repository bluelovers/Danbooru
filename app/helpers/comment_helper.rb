module CommentHelper
	def print_comment(c)
		txt = h(c.body)
		txt.gsub!(/&gt;&gt;\d+/) do |match|
			content_tag("div", link_to("&gt;&gt;#{match[8..-1]}", {:controller => "comment", :action => "show", :id => match[8..-1]}, :onclick => "this.parentNode.innerHTML = $('cbody" + match[8..-1] + "').innerHTML; return false"), :class => "comment-quote")
		end
		txt.gsub!("\n", "<br/>")
		txt.gsub!(/&lt;(?:s|spoilers|spoiler)&gt;(.+?)&lt;\/(?:s|spoilers|spoiler)&gt;/, '<a href="#" class="spoilers">\1</a>')
		txt.gsub!(/(http:\/\/\S+)/, '<a href="\1">\1</a>')
		txt.gsub!(/post #(\d+)/i, '<a href="/post/show/\1">post #\1</a>')
		txt
	end
end
