# The methods added to this helper will be available to all templates in the application.
module ApplicationHelper
	def tag_links(tags)
		if tags
			'/' + Tag.scan_query(tags).map {|t| link_to(t.tr("_", " "), :controller => "post", :action => "index", :tags => t)}.join("+")
		end
	end

	def custom_pagination_links(paginator, options = {})
		options = {:link_to_current_page => false, :always_show_anchors => true, :window_size => 2, :params => {}}.merge(options)

		link_to_current_page = options[:link_to_current_page]
		always_show_anchors = options[:always_show_anchors]
		params = options[:params]
		current_page = paginator.current_page
		window_pages = current_page.window(options[:window_size]).pages

		return if window_pages.length <= 1

		first, last = paginator.first, paginator.last
		html = ''

		unless current_page.first?
			html << link_to("&lt;&lt;", params.merge(:page => current_page.number - 1), :class => "arrow")
		end

		if always_show_anchors and not (wp_first = window_pages[0]).first?
			html << link_to(first.number, params.merge(:page => first.number))
			html << ' ... ' if wp_first.number - first.number > 1
			html << ' '
		end

		window_pages.each do |page|
			if current_page == page && !link_to_current_page
				html << content_tag(:span, number_with_delimiter(page.number))
			else
				html << link_to(number_with_delimiter(page.number), params.merge(:page => page.number))
			end
			html << ' '
		end

		if always_show_anchors and not (wp_last = window_pages[-1]).last?
			html << ' ... ' if last.number - wp_last.number > 1
			html << link_to(number_with_delimiter(last.number), params.merge(:page => last.number))
		end

		unless current_page.last?
			html << link_to("&gt;&gt;", params.merge(:page => current_page.number + 1), :class => "arrow")
		end

		html
	end
end
