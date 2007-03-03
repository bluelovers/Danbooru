module WikiHelper
	def wikilize(text)
		fmt = text.dup

		fmt.gsub!(/^:(.+)$/, '<span style="display: none;">\1</span>')
		fmt.gsub!(/\[\[(.+?)\]\]/) do
			match = $1

			if match =~ /(.+?)\|(.+)/
				link_to $2, :controller => "wiki", :action => "view", :title => $1.gsub(/\s/, '_').downcase
			else
				link_to match, :controller => "wiki", :action => "view", :title => match.gsub(/\s/, '_').downcase
			end
		end

		textilize(fmt)
	end

	def linked_from(to)
		links = to.find_pages_that_link_to_this.map do |page|
			link_to(page.pretty_title, :controller => "wiki", :action => "view", :title => page.title)
		end.join(", ")

		links.empty? ? "None" : links
	end
end
