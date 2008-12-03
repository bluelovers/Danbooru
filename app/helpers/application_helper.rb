module ApplicationHelper
  def navbar_link_to(text, options, html_options = nil)
    if options[:controller] == params[:controller]
      klass = "current-page"
    else
      klass = nil
    end
    
    content_tag("li", link_to(text, options, html_options), :class => klass)
  end

  def format_text(text, options = {})
    DText.parse(text)
  end

  def id_to_color(id)
    r = id % 255
    g = (id >> 8) % 255
    b = (id >> 16) % 255
    "rgb(#{r}, #{g}, #{b})"
  end

  def tag_header(tags)
    unless tags.blank?
      '/' + Tag.scan_query(tags).map {|t| link_to(t.tr("_", " "), :controller => "post", :action => "index", :tags => t)}.join("+")
    end
  end
  
  def compact_time(time)
    if time > Time.now.beginning_of_day
      time.strftime("%H:%M")
    elsif time > Time.now.beginning_of_year
      time.strftime("%b %e")
    else
      time.strftime("%b %e, %Y")
    end
  end
  
  def time_ago_in_words(time)
    from_time = time
    to_time = Time.now
    distance_in_minutes = (((to_time - from_time).abs)/60).round
    distance_in_seconds = ((to_time - from_time).abs).round

    case distance_in_minutes
    when 0..1
      '1 minute'

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
  
  def navigation_links(post)
    html = []
    
    if post.is_a?(Post)
      html << tag("link", :rel => "prev", :title => "Previous Post", :href => url_for(:controller => "post", :action => "show", :id => post.id - 1))
      html << tag("link", :rel => "next", :title => "Next Post", :href => url_for(:controller => "post", :action => "show", :id => post.id + 1))
      
    elsif post.is_a?(Array)
      posts = post
      
      unless posts.previous_page.nil?
        html << tag("link", :href => url_for(params.merge(:page => 1)), :rel => "first", :title => "First Page")
        html << tag("link", :href => url_for(params.merge(:page => posts.previous_page)), :rel => "prev", :title => "Previous Page")
      end

      unless posts.next_page.nil?
        html << tag("link", :href => url_for(params.merge(:page => posts.next_page)), :rel => "next", :title => "Next Page")
        html << tag("link", :href => url_for(params.merge(:page => posts.page_count)), :rel => "last", :title => "Last Page")
      end
    end

    return html.join("\n")
  end  
end
