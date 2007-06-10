require_dependency 'login_system'

class ApplicationController < ActionController::Base
  include LoginSystem
  include ExceptionNotifiable
  local_addresses.clear
  
  before_filter :set_title
  before_filter :current_user
  
  protected
  def render_error(record)
    @record = record
    render :status => 500, :layout => "bare", :inline => "<%= error_messages_for('record') %>"
  end
  
  def set_title(title = CONFIG["app_name"])
    @page_title = title
  end

  def save_tags_to_cookie
    tags = params["tags"] || params["post"]["tags"]
    prev_tags = cookies["recent_tags"].to_s.gsub(/(?:character|char|ch|copyright|copy|artist):/, "").scan(/\S+/)[0..20].join(" ")
    cookies["recent_tags"] = {:value => (tags + " " + prev_tags), :expires => 1.year.from_now}
  end
  
  def cache_key
    a = "#{params[:controller]}/#{params[:action]}"
    tags = params[:tags].to_s.downcase.scan(/\S+/).sort.join(",")
    
    case a
    when "post/index"
      return "p/i/t=#{tags}&p=#{params[:page]}&v=#{$cache_version}"
      
    when "post/show"
      return "p/s/#{params[:id]}&v=#{$cache_version}"
      
    when "post/atom"
      return "p/a/t=#{tags}&v=#{$cache_version}"
    end
  end
  
  def cache_action
    cache = false
    
    if CONFIG["cache_level"] == 1
      cache = (@current_user == nil && request.method == :get)
    elsif CONFIG["cache_level"] == 2
      cache = (request.method == :get)
    end
    
    if cache == true
      key = cache_key()
      cached = Cache.get(key)
      if cached != nil
        render :text => cached, :layout => false
        return false
      end

      yield
      
      if CONFIG["expire_method"].is_a?(Integer)
        Cache.put(key, response.body, CONFIG["expire_method"].days)
      else
        Cache.put(key, response.body)
      end
    else
      yield
    end
  end
  
  public
  def local_request?
    false
  end
end
