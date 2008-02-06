require 'login_system'
# require 'ruby-prof'

class ApplicationController < ActionController::Base
  include LoginSystem
  include ExceptionNotifiable
  local_addresses.clear
  
  before_filter :set_title
  before_filter :set_current_user
  before_filter :init_cookies

  protected
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
      tags += cookies["recent_tags"].to_s.gsub(/(?:character|char|ch|copyright|copy|ambiguous|artist|parent|pool):/, "").scan(/\S+/)
      cookies["recent_tags"] = tags.slice(0, 20).join(" ")
    end
  end
  
  def cache_key
    case "#{controller_name}/#{action_name}"
    when "post/index"
      page = params[:page].to_i
      tags = params[:tags].to_s.downcase.scan(/\S+/).sort
      expiry = 0
      
      if tags.empty?
        if page > 10
          expiry = (rand(4) + 3) * 1.day
          key = "p/i/p=#{page}"
        else
          cache_version = Cache.get("$cache_version").to_i
          key = "p/i/p=#{page}&v=#{cache_version}"
        end
      else
        if page > 10
          expiry = (rand(4) + 3) * 1.day
          key = "p/i/p=#{page}&t=#{tags.join(',')}"
        else
          versioned_tags = tags.map do |x|
            version = Cache.get("tag:#{x}").to_i
            "#{x}:#{version}"
          end

          key = "p/i/p=#{page}&t=#{versioned_tags.join(',')}"
        end
      end
      
      return [key, expiry]
      
    when "post/atom"
      tags = params[:tags].to_s.downcase.scan(/\S+/).sort
      
      if tags.empty?
        cache_version = Cache.get("$cache_version").to_i
        key = "p/a/v=#{cache_version}"
      else
        versioned_tags = tags.map do |x|
          version = Cache.get("tag:#{x}").to_i
          "#{x}:#{version}"
        end

        key = "p/a/t=#{versioned_tags.join(',')}"
      end
      
      return [key, 0]
      
    when "post/show"
      id = params[:id]
      key = "p/s/#{id}"
      return [key, 0]
    
    else
      raise "Unknown action"
    end
  end
  
  def set_cache_headers
    response.headers["Cache-Control"] = "max-age=300"
  end
  
  def cache_action
    # RubyProf.start
    
    if (@current_user == nil || !@current_user.privileged?) && request.method == :get && !%w(xml js).include?(params[:format])
      
      key, expiry = cache_key()
      cached = Cache.get(key)

      unless cached.blank?
        render :text => cached, :layout => false
        return false
      end

      yield

      if response.headers['Status'] =~ /^200/
        Cache.put(key, response.body, expiry)
      end
    else
      yield
    end
    
    # r = RubyProf.stop
    # p = RubyProf::GraphHtmlPrinter.new(r)
    # File.open("profile.html", "w") do |f|
    #   p.print(f, 1)
    # end
  end
  
  def init_cookies
    if @current_user
      if @current_user.has_mail?
        cookies["has_mail"] = "1"
      else
        cookies["has_mail"] = "0"
      end

      if @current_user.privileged? && ForumPost.updated?(@current_user)
        cookies["forum_updated"] = "1"
      else
        cookies["forum_updated"] = "0"
      end

      if @current_user.level == User::LEVEL_BLOCKED
        cookies["block_reason"] = "You have been blocked. Reason: #{@current_user.ban.reason}. Expires: #{@current_user.ban.expires_at.strftime('%Y-%m-%d')}"
      else
        cookies["block_reason"] = ""
      end
      
      if @current_user.always_resize_images?
        cookies["resize_image"] = "1"
      else
        cookies["resize_image"] = "0"
      end
      
      cookies["my_tags"] = @current_user.my_tags      
      cookies["blacklisted_tags"] = @current_user.blacklisted_tags
    end
  end
  
  public
  def local_request?
    false
  end
end
