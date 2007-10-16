# The methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def format_text(text, options = {})
    text = auto_link(simple_format(text)) unless options[:skip_simple_format]
    text = text.gsub(/post #(\d+)/i, '<a href="/post/show/\1">post #\1</a>')
    text = text.gsub(/comment #(\d+)/i, '<a href="/comment/show/\1">post #\1</a>')
    text = text.gsub(/forum #(\d+)/i, '<a href="/forum/show/\1">post #\1</a>')
    text = text.gsub(/&lt;quote&gt;(.+?)&lt;\/quote&gt;/m, '<div class="quote">\1</div>')
    text = text.gsub(/&lt;s&gt;(.+?)&lt;\/s&gt;/m, '<a href="#" class="spoiler">\1</a>')
    text = text.gsub(/(\w+ said:)/, '<em>\1</em>')
    return text
  end
  
  def textilize(text)
    if text.blank?
      return ""
    end

    if Object.const_defined?(:SuperRedCloth)
      textilized = SuperRedCloth.new(text)
      textilized.to_html
    elsif Object.const_defined?(:RedCloth)
      textilized = RedCloth.new(text)
      textilized.to_html
    else
      text
    end
  end

  def id_to_color(id)
    r = id % 255
    g = (id >> 8) % 255
    b = (id >> 16) % 255
    "rgb(#{r}, #{g}, #{b})"
  end

  def tag_header(tags)
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
      'a minute'

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

  # this assumes the paginator is called @pages
  def navigation_links
    html = []
    if @pages
      unless @pages.current.first?
        html << yield('first', 'First Page',  params.merge(:page => @pages.first))
        html << yield('prev', 'Previous Page',  params.merge(:page => @pages.current.number - 1))
      end
      unless @pages.current.last?
        html << yield('next', 'Next Page',  params.merge(:page => @pages.current.number + 1))
        html << yield('last', 'Last Page',  params.merge(:page => @pages.last))
      end
    elsif @post
      html << yield('prev', 'Previous Post', :controller => "post", :action => "show", :id => @post.prev_post_id) if @post.prev_post_id
      html << yield('next', 'Next Post', :controller => "post", :action => "show", :id => @post.next_post_id) if @post.next_post_id
    end
    html.join("\n")
  end
end
