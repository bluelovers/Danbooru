require 'ruby-prof'

class ApplicationController < ActionController::Base
  include ExceptionNotifiable

  # This is a proxy class to make various nil checks unnecessary
  class AnonymousUser
    def id
      nil
    end

    def level
      0
    end

    def name
      "Anonymous"
    end

    def pretty_name
      "Anonymous"
    end

    def is_anonymous?
      true
    end

    def has_permission?(obj, foreign_key = :user_id)
      false
    end

    def show_samples?
      true
    end

    CONFIG["user_levels"].each do |name, value|
      normalized_name = name.downcase.gsub(/ /, "_")

      define_method("is_#{normalized_name}?") do
        false
      end

      define_method("is_#{normalized_name}_or_higher?") do
        false
      end

      define_method("is_#{normalized_name}_or_lower?") do
        true
      end
    end
  end
  
  module LoginSystem
    protected
    def access_denied
      previous_url = params[:url] || request.request_uri

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Access denied"; redirect_to(:controller => "user", :action => "login", :url => previous_url)}
        fmt.xml {render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 403}
        fmt.json {render :json => {:success => false, :reason => "access denied"}.to_json, :status => 403}
      end
    end

    def set_current_user
      if RAILS_ENV == "test" && session[:user_id]
        @current_user = User.find_by_id(session[:user_id])
      end

      if @current_user == nil && session[:user_id]
        @current_user = User.find_by_id(session[:user_id])
      end

      if @current_user == nil && cookies[:login] && cookies[:pass_hash]
        @current_user = User.authenticate_hash(cookies[:login], cookies[:pass_hash])
      end

      if @current_user == nil && params[:login] && params[:password_hash]
        @current_user = User.authenticate_hash(params[:login], params[:password_hash])
      end

      if @current_user == nil && params[:user]
        @current_user = User.authenticate(params[:user][:name], params[:user][:password])
      end

      if @current_user
        if @current_user.is_blocked? && @current_user.ban && @current_user.ban.expires_at < Time.now
          @current_user.update_attribute(:level, CONFIG["starting_level"])
          Ban.destroy_all("user_id = #{@current_user.id}")
        end

        session[:user_id] = @current_user.id
      else
        @current_user = AnonymousUser.new
      end

      # For convenient access in activerecord models
      Thread.current["danbooru-user_id"] = @current_user.id
      Thread.current["danbooru-ip_addr"] = request.remote_ip
    end

    CONFIG["user_levels"].each do |name, value|
      normalized_name = name.downcase.gsub(/ /, "_")

      define_method("#{normalized_name}_only") do
        if @current_user.__send__("is_#{normalized_name}_or_higher?")
          return true
        else
          access_denied()
        end
      end
    end
  end

  module RespondToHelpers
  protected
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
    
  end
  
  include LoginSystem
  include RespondToHelpers
  include ExceptionNotifiable
  include CacheHelper
  local_addresses.clear
  
  before_filter :set_title
  before_filter :set_current_user
  before_filter :init_cookies
  around_filter :run_profile
  
  protected :build_cache_key
  protected :get_cache_key

protected
  def run_profile
    return yield if params[:profile].nil?
    result = RubyProf.profile {yield}
    printer = RubyProf::GraphPrinter.new(result)
    out = StringIO.new
    printer.print(out, 0)
    response.body.replace(out.string)
    response.content_type = "text/plain"
  end

  def set_title(title = CONFIG["app_name"])
    @page_title = CGI.escapeHTML(title)
  end

  def save_tags_to_cookie
    if params[:tags] || (params[:post] && params[:post][:tags])
      tags = Tag.scan_tags(params[:tags] || params[:post][:tags])
      tags = TagAlias.to_aliased(tags) + Tag.scan_tags(cookies["recent_tags"])
      cookies["recent_tags"] = tags.slice(0, 20).join(" ")
    end
  end

  def check_load_average
    current_load = Sys::CPU.load_avg[1]

    if request.get? &&current_load > CONFIG["load_average_threshold"] && @current_user.is_member_or_lower?
      render :file => "#{RAILS_ROOT}/public/503.html", :status => 503
      return false
    end
  end
  
  def set_cache_headers
    response.headers["Cache-Control"] = "max-age=300"
  end
  
  def cache_action
    if request.method == :get && request.env !~ /Googlebot/ && params[:format] != "xml" && params[:format] != "json"
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
