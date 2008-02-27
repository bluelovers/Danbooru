module LoginSystem
  # This is a proxy class to make various nil checks unnecessary
  class AnonymousUser
    def id
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
  
  protected
  def access_denied
    respond_to do |fmt|
      fmt.html {flash[:notice] = "Access denied"; redirect_to(:controller => "user", :action => "login")}
      fmt.xml {render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 403}
      fmt.js {render :json => {:success => false, :reason => "access denied"}.to_json, :status => 403}
    end
  end

  def set_current_user
    if @current_user == nil && session[:user_id]
      @current_user = User.find(session[:user_id])
    end

    if @current_user == nil && cookies[:login] && cookies[:pass_hash]
      @current_user = User.authenticate_hash(cookies[:login], cookies[:pass_hash])
    end

    if @current_user == nil && params[:user]
      @current_user = User.authenticate(params[:user][:name], params[:user][:password])
    end
    
    if @current_user
      if @current_user.is_blocked? && @current_user.ban.expires_at < Time.now
        @current_user.update_attributes(:level => CONFIG["starting_level"])
        Ban.destroy_all("user_id = #{@current_user.id}")
      end
      
      session[:user_id] = @current_user.id
    else
      @current_user = AnonymousUser.new
    end
  end
  
  def member_only
    if @current_user.is_member_or_higher?
      return true
    else
      access_denied()
    end
  end
  
  def privileged_only
    if @current_user.is_privileged_or_higher?
      return true
    else
      access_denied()
    end
  end

  def mod_only
    if @current_user.is_mod_or_higher?
      return true
    else
      access_denied()
    end
  end

  def blocked_only
    if @current_user.is_blocked_or_higher?
      return true
    else
      access_denied()
    end
  end 

  def admin_only
    if @current_user.is_admin_or_higher?
      return true
    else
      access_denied()
    end
  end
end
