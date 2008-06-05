require 'cache'

module ApplicationHelper
  def simple_format(text)
    text.to_s.gsub(/\r\n?/, "\n").gsub(/\n/, '<br>')
  end
  
  def format_text(text, options = {})
    text = hs(text)

    unless options[:skip_simple_format]
      text = simple_format(text)
    end

    text.gsub!(/(http:\/\/[a-zA-Z0-9_.\/~%?&=;,-]+)/) do
      link = $1
      url = link.gsub(/[.;,:'"]+$/, "")
      link_to link, url
    end
    text.gsub!(/post #(\d+)/i, '<a href="/post/show/\1">post #\1</a>')
    text.gsub!(/comment #(\d+)/i, '<a href="/comment/show/\1">comment #\1</a>')
    text.gsub!(/forum #(\d+)/i, '<a href="/forum/show/\1">forum #\1</a>')
    text.gsub!(/\[quote\](.+?)\[\/quote\]/m, '<div class="quote">\1</div>')
    text.gsub!(/<p><div/, "<div")
    text.gsub!(/<\/div><\/p>/, "</div>")
    text.gsub!(/\[spoilers?\](.+?)\[\/spoilers?\]/m, '<a href="#" class="spoiler">\1</a>')
    text.gsub!(/(\w+ said:)/, '<em>\1</em>')
    text.gsub!(/\[\[(.+?)\]\]/) do
      match = $1

      if match =~ /(.+?)\|(.+)/
        link_to $2, :controller => "wiki", :action => "show", :title => $1.gsub(/\s/, '_').downcase
      else
        link_to match, :controller => "wiki", :action => "show", :title => match.gsub(/\s/, '_').downcase
      end
    end
    text.gsub!(/<\/div>(?:<br>)+/, "</div>")

    return text
  end
  
  def textilize(text)
    if text.blank?
      return ""
    end

    text = text.gsub(/&lt;notextile&gt;/, "<notextile>")
    text = text.gsub(/&lt;\/notextile&gt;/, "</notextile>")

    textilized = SuperRedCloth.new(text)
    textilized.to_html
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
        html << tag("link", params.merge(:page => 1, :rel => "first", :title => "First Page"))
        html << tag("link", params.merge(:page => posts.previous_page, :rel => "prev", :title => "Previous Page"))
      end

      unless posts.next_page.nil?
        html << tag("link", params.merge(:page => posts.next_page, :rel => "next", :title => "Next Page"))
        html << tag("link", params.merge(:page => posts.page_count, :rel => "last", :title => "Last Page"))
      end
    end

    return html.join("\n")
  end
  
  def build_cache_key(base, tags, page)
    page = page.to_i
    page = 1 if page < 1

    tags = tags.to_s.downcase.scan(/\S+/).sort
    version_fragment = "v=?"
    tag_fragment = "t=?"
    page_fragment = "p=#{page}"
    global_version = Cache.get("$cache_version").to_i
    expiry = 0
    
    if (CONFIG["enable_aggressive_caching"] && page > 10) || tags.any? {|x| x =~ /[*:]/}
      version_fragment = "v=#{global_version}"
      tag_fragment = "t=" + tags.join(",")
      expiry = (rand(4) * 3) * 1.day
    else
      tag_fragment = tags.map {|x| x + ":" + Cache.get("tag:#{x}").to_i.to_s}.join(",")
    end
    
    ["#{base}/#{version_fragment}&#{tag_fragment}&#{page_fragment}", expiry]
  end

  def get_cache_key(controller_name, action_name, params)
    case "#{controller_name}/#{action_name}"
    when "post/index"
      build_cache_key("p/i", params[:tags], params[:page])
      
    when "post/atom"
      build_cache_key("p/a", params[:tags], 1)

    when "post/piclens"
      build_cache_key("p/p", params[:tags], params[:page])
      
    else
      nil
    end
  end
end
