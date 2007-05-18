# The methods added to this helper will be available to all templates in the application.
module ApplicationHelper
	def tag_links(tags)
		if tags
			'/' + Tag.scan_query(tags).map {|t| link_to(t.tr("_", " "), :controller => "post", :action => "index", :tags => t)}.join("+")
		end
	end

	def time_ago_in_words(time)
		from_time = time
		to_time = Time.now
		distance_in_minutes = (((to_time - from_time).abs)/60).round
		distance_in_seconds = ((to_time - from_time).abs).round

		case distance_in_minutes
		when 0..1
			return (distance_in_minutes == 0) ? 'less than a minute' : '1 minute'

		when 2..44
			"#{distance_in_minutes} minutes"

		when 45..89
			'1 hour'

		when 90..1439
			"#{(distance_in_minutes.to_f / 60.0).round} hours"

		when 1440..2879
			'1 day'

		when 2880..43199
			"#{(distance_in_minutes / 1440).round} days"

		when 43200..86399
			'1 month'

		when 86400..525959
			"#{(distance_in_minutes / 43200).round} months"

		when 525960..1051919
			'1 year'

		else
			"over #{(distance_in_minutes / 525960).round} years"
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
