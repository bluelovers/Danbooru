require_dependency "user"

module LoginSystem
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

    if @current_user == nil && params[:login] && params[:password_hash]
      @current_user = User.authenticate_hash(params[:login], params[:password_hash])
    end

    if @current_user == nil && cookies[:login] && cookies[:pass_hash]
      @current_user = User.authenticate_hash(cookies[:login], cookies[:pass_hash])
    end

    if @current_user == nil && params[:user]
      @current_user = User.authenticate(params[:user][:name], params[:user][:password])
    end
    
    if @current_user
      if @current_user.ip_addr != request.remote_ip
        @current_user.update_attribute(:ip_addr, request.remote_ip)
      end
      
      if @current_user.last_logged_in_at < 1.week.ago
        @current_user.update_attribute(:last_logged_in_at, Time.now)
      end
      
      if @current_user.level == User::LEVEL_BLOCKED && @current_user.ban.expires_at < Time.now
        @current_user.update_attribute(:level, User::LEVEL_MEMBER)
        Ban.destroy_all("user_id = #{@current_user.id}")
      end
      
      session[:user_id] = @current_user.id
    end
  end

  def member_only
    if @current_user && @current_user.member?
      return true
    else
      access_denied()
      return false
    end
  end
  
  def privileged_only
    if @current_user && @current_user.privileged?
      return true
    else
      access_denied()
      return false
    end
  end

  def mod_only
    if @current_user && @current_user.mod?
      return true
    else
      access_denied()
      return false
    end
  end

  def blocked_only
    if @current_user && @current_user.level <= User::LEVEL_BLOCKED
      access_denied()
      return false
    else
      return true
    end
  end 

  def admin_only
    if @current_user && @current_user.admin?
      return true
    else
      access_denied()
      return false
    end
  end
end
