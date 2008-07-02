require 'login_system'

class ApplicationController < ActionController::Base
  include LoginSystem
  include ExceptionNotifiable
  include CacheHelper
  local_addresses.clear
  
  before_filter :set_title
  before_filter :set_current_user
  before_filter :init_cookies
  
  protected :build_cache_key
  protected :get_cache_key

  protected
  def check_load_average
    current_load = Sys::CPU.load_avg[1]
    
    if request.get? && request.env["HTTP_USER_AGENT"] !~ /Google/ && current_load > CONFIG["load_average_threshold"] && @current_user.is_member_or_lower?
      render :file => "#{RAILS_ROOT}/public/503.html", :status => 503
      return false
    end
  end
  
  def respond_to_success(notice, redirect_to_params, options = {})
    extra_api_params = options[:api] || {}
    
    respond_to do |fmt|
      fmt.html {flash[:notice] = notice ; redirect_to(redirect_to_params)}
      fmt.json {render :json => extra_api_params.merge(:success => true).to_json}
      fmt.xml {render :xml => extra_api_params.merge(:success => true).to_xml(:root => "response")}
    end
  end
  
  def respond_to_error(obj, redirect_to_params, options = {})
    extra_api_params = options[:api] || {}
    status = options[:status] || 500
    
    if obj.is_a?(ActiveRecord::Base)
      obj = obj.errors.full_messages.join(", ")
      status = 420
    end
    
    case status
    when 420
      status = "420 Invalid Record"
      
    when 421
      status = "421 User Throttled"
      
    when 422
      status = "422 Locked"
      
    when 423
      status = "423 Already Exists"
      
    when 424
      status = "424 Invalid Parameters"
    end
    
    respond_to do |fmt|
      fmt.html {flash[:notice] = "Error: #{obj}" ; redirect_to(redirect_to_params)}
      fmt.json {render :json => extra_api_params.merge(:success => false, :reason => obj).to_json, :status => status}
      fmt.xml {render :xml => extra_api_params.merge(:success => false, :reason => obj).to_xml(:root => "response"), :status => status}
    end
  end
  
  def respond_to_list(inst_var_name)
    inst_var = instance_variable_get("@#{inst_var_name}")
    
    respond_to do |fmt|
      fmt.html
      fmt.json {render :json => inst_var.to_json}
      fmt.xml {render :xml => inst_var.to_xml(:root => inst_var_name)}
    end
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
      tags = TagAlias.to_aliased((params[:tags] || params[:post][:tags]).downcase.scan(/\S+/))
      tags += cookies["recent_tags"].to_s.scan(/\S+/)
      cookies["recent_tags"] = tags.slice(0, 20).join(" ")
    end
  end
  
  def set_cache_headers
    response.headers["Cache-Control"] = "max-age=300"
  end
  
  def cache_action
    if request.method == :get && params[:format] != "xml" && params[:format] != "json"
      key, expiry = get_cache_key(controller_name, action_name, params, :user => @current_user)
      
      if key && key.size < 200
        cached = Cache.get(key)

        unless cached.blank?
          render :text => cached, :layout => false
          return
        end
      end

      yield

      if key && response.headers['Status'] =~ /^200/
        Cache.put(key, response.body, expiry)
      end
    else
      yield
    end
  end
  
  def init_cookies
    unless @current_user.is_anonymous?
      if @current_user.has_mail?
        cookies["has_mail"] = "1"
      else
        cookies["has_mail"] = "0"
      end

      if @current_user.is_privileged_or_higher? && ForumPost.updated?(@current_user)
        cookies["forum_updated"] = "1"
      else
        cookies["forum_updated"] = "0"
      end

      if @current_user.is_blocked?
        if @current_user.ban
          cookies["block_reason"] = "You have been blocked. Reason: #{@current_user.ban.reason}. Expires: #{@current_user.ban.expires_at.strftime('%Y-%m-%d')}"
        else
          cookies["block_reason"] = "You have been blocked."
        end
      else
        cookies["block_reason"] = ""
      end
      
      if @current_user.always_resize_images?
        cookies["resize_image"] = "1"
      else
        cookies["resize_image"] = "0"
      end
      
      cookies["my_tags"] = @current_user.my_tags      
      cookies["blacklisted_tags"] = @current_user.blacklisted_tags_array
    else
      cookies["blacklisted_tags"] = CONFIG["default_blacklists"]
    end
  end
end
