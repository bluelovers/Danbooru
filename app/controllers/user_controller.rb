require 'digest/sha2'

class UserController < ApplicationController
  layout "default"
  verify :method => :post, :only => [:authenticate, :update, :create]
  before_filter :blocked_only, :only => [:authenticate, :update, :edit]
  before_filter :member_only, :only => [:show]
  before_filter :janitor_only, :only => [:invites, :revert_tag_changes]
  before_filter :mod_only, :only => [:block, :unblock, :show_blocked_users]
  before_filter :admin_only, :only => [:edit_upload_limit, :update_upload_limit]
  helper :post, :tag_subscription
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
    @users = User.find(:all, :order => "lower(name)", :conditions => ["level = ? AND name ILIKE ? ESCAPE E'\\\\'", CONFIG["user_levels"]["Member"], params[:member][:name] + "%"])
    render :layout => false
  end

  def show
    if params[:name]
      @user = User.find_by_name(params[:name])
    else
      @user = User.find_by_id(params[:id])
    end

    if @user.nil?
      redirect_to "/404.html"
    end
  end
  
  def invites
    if request.post?
      if params[:member]
        begin
          @current_user.invite!(params[:member][:name], params[:member][:level])
          flash[:notice] = "User was invited"
          
        rescue ActiveRecord::RecordNotFound
          flash[:notice] = "Account not found"
          
        rescue User::InvitationError => x
          flash[:notice] = x.message
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
    
    @users = User.paginate(User.generate_sql(params).merge(:per_page => 20, :page => params[:page]))
    respond_to_list("users")
  end

  def authenticate
    save_cookies(@current_user)
    
    if params[:url].blank?
      path = {:action => "home"}
    else
      path = params[:url]
    end
    
    respond_to_success("You are now logged in", path)
  end

  def login
    set_title "Login"
  end

  def create
    user = User.create(params[:user].merge(:ip_addr => request.remote_ip))

    if user.errors.empty?
      save_cookies(user)
      flash[:notice] = "New account created"
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
    @user.comment_threshold = 0
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
      cookies.delete(:hide_resized_notice)
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
      
      if @user.nil?
        flash[:notice] = "That account does not exist"
        redirect_to :action => "reset_password"
        return
      end
      
      if @user.email.blank?
        flash[:notice] = "You never supplied an email address, therefore you cannot have your password automatically reset"
        redirect_to :action => "login"
        return
      end
      
      if @user.email != params[:user][:email]
        flash[:notice] = "That is not the email address you supplied"
        redirect_to :action => "login"
        return
      end
      
      begin
        User.transaction do
          # If the email is invalid, abort the password reset
          new_password = @user.reset_password
          UserMailer.deliver_new_password(@user, new_password)
          flash[:notice] = "Password reset. Check your email in a few minutes."
        end
      rescue Net::SMTPSyntaxError, Net::SMTPFatalError
        flash[:notice] = "Your email address was invalid"
      end
      
      redirect_to :action => "login"
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
      
      Ban.create(params[:ban].merge(:banned_by => @current_user.id, :user_id => params[:id]))
      redirect_to :action => "show_blocked_users"
    else
      @ban = Ban.new(:user_id => @user.id, :duration => "1")
    end
  end
  
  def unblock
    params[:user].keys.each do |user_id|
      Ban.destroy_all(["user_id = ?", user_id])
      user = User.find(user_id)
      user.level = CONFIG["user_levels"]["Member"]
      user.save
    end
    
    redirect_to :action => "show_blocked_users"
  end
  
  def show_blocked_users
    @users = User.find(:all, :select => "users.*", :joins => "JOIN bans ON bans.user_id = users.id", :conditions => ["bans.banned_by = ?", @current_user.id])
  end  
  
  def upload_limit
    @pending_count = Post.count(:conditions => ["user_id = ? AND status = ?", @current_user.id, "pending"])
    @approved_count = Post.count(:conditions => ["user_id = ? AND status = ?", @current_user.id, "active"])
    @deleted_count = Post.count(:conditions => ["user_id = ? AND status = ?", @current_user.id, "deleted"])
  end
  
  def edit_upload_limit
    @user = User.find(params[:id])
  end
  
  def update_upload_limit
    @user = User.find(params[:id])
    @user.base_upload_limit = params[:user][:base_upload_limit]
    @user.save
    flash[:notice] = "User updated"
    redirect_to :action => "show", :id => @user.id
  end
  
  def random
    @user = User.find(params[:id])
    @posts = Post.find(:all, :conditions => ["user_id = ?", @user.id], :order => "random()", :limit => 50)
  end
  
  def calculate_uploaded_tags
    if request.post?
      if params[:commit] == "Yes"
        JobTask.create(:task_type => "calculate_uploaded_tags", :data => {"id" => @current_user.id}, :status => "pending")
        flash[:notice] = "Uploaded tags are being calculated. Please check back in 5-10 minutes."
      end
      redirect_to :action => "show", :id => @current_user.id
    end
  end
  
  def revert_changes
    @user = User.find(params[:id])
    
    if request.post?
      if params[:commit] == "Revert tag and rating edits"
        PostTagHistory.undo_changes_by_user(@user.id)
        flash[:notice] = "Changes were reverted"
        redirect_to :controller => "post_tag_history", :action => "index"
      elsif params[:commit] == "Revert note edits"
        Note.undo_changes_by_user(@user.id)
        flash[:notice] = "Changes were reverted"
        redirect_to :controller => "note", :action => "history"
      end
    end
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
        
        UserMailer::deliver_confirmation_email(user)
        flash[:notice] = "Confirmation email sent"
        redirect_to :action => "home"
      end
    end

    def activate_user
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
