require 'digest/sha2'

class UserController < ApplicationController
  layout "default"
  verify :method => :post, :only => [:authenticate, :update, :create, :add_favorite, :delete_favorite, :unban]
  before_filter :blocked_only, :only => [:authenticate, :update, :edit]
  before_filter :mod_only, :only => [:invites, :block, :unblock, :show_blocked_users]
  helper :post
  filter_parameter_logging :password
  auto_complete_for :user, :name

  protected
  def save_cookies(user)
    cookies[:login] = {:value => user.name, :expires => 1.year.from_now}
    cookies[:pass_hash] = {:value => user.password_hash, :expires => 1.year.from_now}
    session[:user_id] = user.id
  end

  public
  def auto_complete_for_member_name
    @users = User.find(:all, :order => "lower(name)", :conditions => ["level = ? AND name ILIKE ? ESCAPE '\\\\'", CONFIG["user_levels"]["Member"], params[:member][:name] + "%"])
    render :layout => false, :text => "<ul>" + @users.map {|x| "<li>" + x.name + "</li>"}.join("") + "</ul>"
  end

  def show
    @user = User.find(params[:id])
  end
  
  def invites
    if request.post?
      if params[:member]
        if @current_user.invite_count < 1
          flash[:notice] = "You are out of invites"
        else
          user = User.find(:first, :conditions => ["lower(name) = lower(?)", params[:member][:name]])

          if user == nil
            flash[:notice] = "User #{params[:member][:name]} was not found"
            redirect_to :action => "invites"
            return
          end
          
          if UserRecord.count(:conditions => ["user_id = ? AND is_positive = false AND reported_by IN (SELECT id FROM users WHERE level >= ?)", user.id, CONFIG["user_levels"]["Mod"]]) > 0 && !@current_user.is_mod_or_higher?
            flash[:notice] = "This user has negative feedback on his record and can only be invited by a moderator"
            redirect_to :action => "invites"
            return
          end

          user.level = CONFIG["user_levels"]["Privileged"]
          user.invited_by = @current_user.id
          User.transaction do
            user.save!
            @current_user.decrement! :invite_count
          end
          flash[:notice] = "You have invited #{CGI.escapeHTML(user.pretty_name)}"
        end
      end
      
      redirect_to :action => "invites"
    else
      @invited_users = User.find(:all, :conditions => ["invited_by = ?", @current_user.id], :order => "lower(name)")
    end
  end
  
  def home
    set_title "My Account"
  end

  def index
    set_title "Users"
    
    @users = User.paginate User.generate_sql(params).merge(:per_page => 20, :page => params[:page])
    respond_to_list("users")
  end

  def authenticate
    save_cookies(@current_user)
    respond_to_success("You are now logged in", :action => "home")
  end

  def login
    set_title "Login"
  end

  def create
    user = User.new(params[:user])
    user.name = params[:user][:name]
    user.save

    if user.errors.empty?
      save_cookies(user)

      if CONFIG["enable_account_email_activation"]
        begin
          UserMailer::deliver_confirmation_email(user, User.confirmation_hash(user.name))
          notice = "New account created. Confirmation email sent to #{user.email}"
        rescue Net::SMTPSyntaxError, Net::SMTPFatalError
          notice = "Could not send confirmation email; account creation canceled"
          user.destroy
        end
      else
        notice = "New account created"
      end

      flash[:notice] = notice
      redirect_to :action => "home"
    else
      error = user.errors.full_messages.join(", ")
      flash[:notice] = "Error: " + error
      redirect_to :action => "signup"
    end
  end

  def signup
    set_title "Signup"
    @user = User.new
  end

  def logout
    set_title "Logout"
    session[:user_id] = nil
    cookies[:login] = nil
    cookies[:pass_hash] = nil

    respond_to_success("You are now logged out", :action => "home")
  end

  def update
    if params[:commit] == "Cancel"
      redirect_to :action => "home"
      return
    end
    
    if @current_user.update_attributes(params[:user])
      respond_to_success("Account settings saved", :action => "home")
    else
      respond_to_error(@current_user, :action => "edit")
    end
  end

  def edit
    set_title "Edit Account"
    @user = @current_user
  end
  
  def reset_password
    set_title "Reset Password"

    if request.post?
      @user = User.find_by_name(params[:user][:name])
      
      if @user
        if @user.email.blank?
          flash[:notice] = "You never supplied an email address, therefore you cannot have your password automatically reset"
          redirect_to :action => "login"
        else
          begin
            User.transaction do
              # If the email is invalid, abort the password reset
              new_password = @user.reset_password
              UserMailer.deliver_new_password(@user, new_password)
              flash[:notice] = "Password reset. Check your email in a few minutes"
            end
          rescue Net::SMTPSyntaxError, Net::SMTPFatalError
            flash[:notice] = "Your email address was invalid"
          end
          
          redirect_to :action => "login"
        end
      else
        flash[:notice] = "That account does not exist"
        redirect_to :action => "reset_password"
      end
    else
      @user = User.new
    end
  end
  
  def block
    @user = User.find(params[:id])
    
    if request.post?
      if @user.is_mod_or_higher?
        flash[:notice] = "You can not ban other moderators or administrators"
        redirect_to :action => "block"
        return
      end
      
      @user.update_attribute(:level, CONFIG["user_levels"]["Blocked"])
      Ban.create(params[:ban].merge(:banned_by => @current_user.id))
      redirect_to :action => "show_blocked_users"
    else
      @ban = Ban.new(:user_id => @user.id, :duration => "1")
    end
  end
  
  def unblock
    params[:user].keys.each do |user_id|
      Ban.destroy_all(["user_id = ?", user_id])
    end
    
    redirect_to :action => "show_blocked_users"
  end
  
  def show_blocked_users
    @users = User.find(:all, :select => "users.*", :joins => "JOIN bans ON bans.user_id = users.id", :conditions => ["bans.banned_by = ?", @current_user.id])
  end  
  
  if CONFIG["enable_account_email_activation"]
    def resend_confirmation
      if request.post?
        user = User.find_by_email(params[:email])
        
        if user.nil?
          flash[:notice] = "No account exists with that email"
          redirect_to :action => "home"
          return
        end
        
        if user.is_blocked_or_higher?
          flash[:notice] = "Your account is already activated"
          redirect_to :action => "home"
          return
        end
        
        UserMailer::deliver_confirmation_email(user, User.confirmation_hash(user.name))
        flash[:notice] = "Confirmation email sent"
        redirect_to :action => "home"
      end
    end

    def activate_user
      if params["id"] !~ /\A[0-9a-f]{64}\Z/
        flash[:notice] = "Invalid confirmation code"
        redirect_to :action => "home"
        return
      end

      flash[:notice] = "Invalid confirmation code"
      
      users = User.find(:all, :conditions => ["level = ?", CONFIG["user_levels"]["Unactivated"]])
      users.each do |user|
        if User.confirmation_hash(user.name) == params["hash"]
          user.update_attribute(:level, CONFIG["starting_level"])
          flash[:notice] = "Account has been activated"
          break
        end
      end

      redirect_to :action => "home"
    end
  end
end
