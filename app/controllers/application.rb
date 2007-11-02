require 'login_system'

class ApplicationController < ActionController::Base
  include LoginSystem
  include ExceptionNotifiable
  local_addresses.clear
  
  helper_method :hide_unsafe_posts?
  before_filter :set_title
  before_filter :set_current_user

  protected
  def hide_unsafe_posts?
    CONFIG["hide_unsafe_posts"] && (@current_user == nil || !@current_user.privileged?)
  end

  def render_error(record)
    @record = record
    render :status => 500, :layout => "bare", :inline => "<%= error_messages_for('record') %>"
  end
  
  def set_title(title = CONFIG["app_name"])
    @page_title = CGI.escapeHTML(title)
  end

  def save_tags_to_cookie
    if params[:tags] || (params[:post] && params[:post][:tags])
      tags = TagAlias.to_aliased((params[:tags] || params[:post][:tags]).scan(/\S+/))
      tags += cookies["recent_tags"].to_s.gsub(/(?:character|char|ch|copyright|copy|ambiguous|amb|artist|parent|pool):/, "").scan(/\S+/)
      cookies["recent_tags"] = {:value => tags.slice(0, 30).join(" "), :expires => 1.year.from_now}
    end
  end
  
  def cache_key
    a = "#{params[:controller]}/#{params[:action]}"
    tags = params[:tags].to_s.downcase.scan(/\S+/).sort.map do |x|
      version = CACHE.get("tag:" + x, true).to_i
      "#{x}:#{version}"
    end.join(",")

    case a
    when "post/index"
      page = params[:page].to_i
      page = 1 if page == 0

      if tags.empty?
        key = "p/i/p=#{page}&v=#{$cache_version}"
      elsif tags.include?(":")
        # The presence of a colon implies a meta-tag, which won't be
        # expired automatically.
        key = "p/i/t=#{tags}&p=#{page}&v=#{$cache_version}"
      else
        key = "p/i/t=#{tags}&p=#{page}"
      end
      
    when "post/atom"
      if tags.empty?
        key = "p/a/v=#{$cache_version}"
      elsif tags.include?(":")
        # The presence of a colon implies a meta-tag, which won't be
        # expired automatically.
        key = "p/a/t=#{tags}&v=#{$cache_version}"
      else
        key = "p/a/t=#{tags}"
      end
    end

    return key
  end
  
  def cache_action
    if @current_user == nil && request.method == :get && !%w(xml js).include?(params[:format])
      key = cache_key()
      cached = Cache.get(key)
      unless cached.blank?
        render :text => cached, :layout => false
        return false
      end

      yield
      
      Cache.put(key, response.body)
    else
      yield
    end
  end
  
  public
  def local_request?
    false
  end
end
