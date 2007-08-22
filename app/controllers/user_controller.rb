require 'digest/sha2'

class UserController < ApplicationController
	layout "default"
	verify :method => :post, :only => [:authenticate, :update, :create, :add_favorite, :delete_favorite]
	before_filter :user_only, :only => [:favorites, :authenticate, :update, :invites, :add_favorite, :delete_favorite]
  helper :post
  auto_complete_for :user, :name

	protected
	def save_cookies(user)
		cookies[:login] = {:value => user.name, :expires => 1.year.from_now}
		cookies[:pass_hash] = {:value => user.password, :expires => 1.year.from_now}
		session[:user_id] = user.id
	end

	def confirmation_hash(name)
		Digest::SHA256.hexdigest("~-#{name}-~#{User.salt}")
	end

	public
	def home
		set_title "My Account"
	end

  def index
    if params[:id]
      @users = [User.find(:first, :conditions => ["id = ?", params[:id]])]
    elsif params[:name]
      @users = User.find(:all, :conditions => ["name ilike ? escape '\\\\'", "%" + params[:name].to_escaped_for_sql_like + "%"], :order => "lower(name)")
    else
      @users = User.find(:all, :order => "lower(name)")
    end

    respond_to do |fmt|
      fmt.xml {render :xml => @users.to_xml}
      fmt.js {render :json => @users.to_json}
    end
  end

	def authenticate
		save_cookies(@current_user)
		@current_user.increment! :login_count

		respond_to do |fmt|
			fmt.html {flash[:notice] = "You are now logged in"; redirect_to(:action => "home")}
			fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def login
		set_title "Login"
	end

	def create
		if !CONFIG["enable_signups"] && (!CONFIG["enable_invites"] || (CONFIG["enable_invites"] && !params[:key]))
			flash[:notice] = "Signups disabled"
			redirect_to :action => "login"
			return
		end

		if CONFIG["enable_invites"] && params[:key]
			@invite = Invite.find(:first, :conditions => ["email = ? AND activation_key = ?", params[:user][:email], params[:key]])

			if @invite == nil
				flash[:notice] = "Either the activation key was incorrect or the invite was not found"
				redirect_to :action => "login"
				return
			end
      inviter_id = @invite.user_id
    else
      inviter_id = nil
		end

		user = User.create(params[:user].merge(:invited_by => inviter_id))

		if user.errors.empty?
			@invite.destroy if @invite
			save_cookies(user)

			if CONFIG["enable_account_email_activation"]
				UserMailer::deliver_confirmation_email(user, confirmation_hash(user.name))
				notice = "New account created. Confirmation email sent to #{user.email}"
			else
				notice = "New account created"
			end

			flash[:notice] = notice
			redirect_to :action => "home"
		else
			error = user.errors.full_messages.join(", ")
			flash[:notice] = "Error: " + error
			redirect_to :action => "login"
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

		respond_to do |fmt|
			fmt.html {flash[:notice] = "You are now logged out"; redirect_to(:action => "home")}
			fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def update
		if @current_user.update_attributes(params[:user])
			flash[:notice] = "Account settings saved"
			redirect_to :action => "home"
		else
			error = @current_user.errors.full_messages.join(", ")
			flash[:notice] = "Error: " + error
			redirect_to :action => "edit"
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
					new_password = @user.reset_password!
					UserMailer.deliver_new_password(@user, new_password)

					flash[:notice] = "Password reset. Check your email in a few minutes"
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

	if CONFIG["enable_account_email_activation"]
		def resend_confirmation
			user = @current_user
			if user.activated?
				flash[:notice] = "Account already activated"
				redirect_to :action => "home"
				return
			end

			UserMailer::deliver_confirmation_email(user, confirmation_hash(user.name))
			flash[:notice] = "Confirmation email sent to #{user.email}"
			redirect_to :action => "home"
		end

		def activate_user
			if params["id"] !~ /\A[0-9a-f]{64}\Z/
				flash[:notice] = "Invalid confirmation code"
				redirect_to :action => "home"
				return
			end

			users = User.find(:all, :conditions => ["level = ?", User::LEVEL_UNACTIVATED])

			users.each do |user|
				if confirmation_hash(user.name) == params["hash"]
					user.update_attribute(:level, User::LEVEL_MEMBER)
	
					flash[:notice] = "Account has been activated"
					redirect_to :action => "home"
					break
				end
			end

			flash[:notice] = "Invalid confirmation code"
			redirect_to :action => "home"
		end
	end
end
