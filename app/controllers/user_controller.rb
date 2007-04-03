require 'digest/sha2'

class UserController < ApplicationController
	layout "default"
	before_filter :user_only, :only => [:favorites, :authenticate, :update, :invites]
	verify :method => :post, :only => [:authenticate, :update, :create]

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

	def authenticate
		save_cookies(@current_user)
		@current_user.increment! :login_count

		respond_to do |fmt|
			fmt.html {flash[:notice] = "You are now logged in"; redirect_to(:action => "home")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def login
		set_title "Login"
	end

	def create
		if CONFIG["enable_signups"]
			if params[:key]
				invite = Invite.find(:first, :conditions => ["email = ? AND activation_key = ?", params[:user][:email], params[:key]])
				if invite
					invite.destroy
				else
					access_denied()
					return
				end
			else
				respond_to do |fmt|
					fmt.html {flash[:notice] = "Signups are disabled"; redirect_to(:action => "home")}
					fmt.xml {render :xml => {:success => false, :reason => "signups are disabled"}.to_xml, :status => 500}
					fmt.js {render :json => {:success => false, :reason => "signups are disabled"}.to_json, :status => 500}
				end
				return
			end
		end

		user = User.create(params[:user].merge(:last_seen_forum_post_date => Time.now))
		if user.errors.empty?
			save_cookies(user)

			if CONFIG["enable_account_email_activation"]
				UserMailer::deliver_confirmation_email(user, confirmation_hash(user.name))
				notice = "New account created. Confirmation email sent to #{user.email}"
			else
				notice = "New account created"
			end

			respond_to do |fmt|
				fmt.html {flash[:notice] = notice; redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => true}.to_xml}
				fmt.js {render :js => {:success => true}.to_json}
			end
		else
			error = user.errors.full_messages.join(", ")
				respond_to do |fmt|
				fmt.html {flash[:notice] = "Error: " + error; redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => false, :reason => h(error)}.to_xml, :status => 500}
				fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
			end
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
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def update
		if @current_user.update_attributes(params[:user])
			respond_to do |fmt|
				fmt.html {flash[:notice] = "Account options saved"; redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => true}.to_xml}
				fmt.js {render :json => {:success => true}.to_json}
			end
		else
			error = @current_user.errors.full_messages.join(", ")
			@current_user.errors.clear

			respond_to do |fmt|
				fmt.html {flash[:notice] = "Error: " + error; redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => false, :reason => error}.to_xml, :status => 500}
				fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
			end
		end
	end

	def edit
		set_title "Edit Account"
		@user = @current_user
	end

	def favorites
		@user = User.find(params["id"])

		set_title "#{@user.name}'s Favorites"
		@pages, @posts = paginate :posts, :per_page => 12, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ?", params["id"]], :select => "posts.*"

		respond_to do |fmt|
			fmt.html
			fmt.xml {render :xml => @posts.to_xml}
			fmt.js {render :json => @posts.to_json}
		end
	end

	def favorites_atom
		@posts = Post.find(:all, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ?", params["id"]], :limit => 24, :select => "posts.*")
		@user = User.find(params["id"])

		render :layout => false
	end

	def reset_password
		set_title "Reset Password"

		if request.post?
			@user = User.find_by_name(params[:user][:name])
			
			if @user
				if @user.email.blank?
					respond_to do |fmt|
						fmt.html {flash[:notice] = "You never supplied an email address, therefore you cannot have your password automatically reset"; redirect_to(:action => "login")}
						fmt.xml {render :xml => {:success => false, :reason => "user has no email address"}.to_xml, :status => 500}
						fmt.js {render :json => {:success => false, :reason => "user has no email address"}.to_json, :status => 500}
					end
				else
					new_password = @user.reset_password!
					UserMailer.deliver_new_password(@user, new_password)

					respond_to do |fmt|
						fmt.html {flash[:notice] = "Password reset. Check your email in a few minutes"; redirect_to(:action => "login")}
						fmt.xml {render :xml => {:success => true}.to_xml}
						fmt.js {render :json => {:success => true}.to_json}
					end
				end
			else
				respond_to do |fmt|
					fmt.html {flash[:notice] = "That account does not exist"; redirect_to(:action => "reset_password")}
					fmt.xml {render :xml => {:success => false, :reason => "user not found"}.to_xml, :status => 500}
					fmt.js {render :json => {:success => false, :reason => "user not found"}.to_json, :status => 500}
				end
			end
		else
			@user = User.new
		end
	end

	def invites
	end

if CONFIG["enable_account_email_activation"]
	def resend_confirmation
		user = @current_user
		if false and user.activated?
			flash[:notice] = "Account already activated"
			redirect_to :action => "home"
			return
		end

		UserMailer::deliver_confirmation_email(user, confirmation_hash(user.name))
		flash[:notice] = "Confirmation email sent to #{user.email}"
		redirect_to :action => "home"
	end

	def activate_user
		if not params["id"] =~ /\A[0-9a-f]{64}\Z/
			respond_to do |fmt|
				fmt.html {flash[:notice] = "Invalid confirmation code"; redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => false}.to_xml}
				fmt.js {render :json => {:success => false}.to_json}
			end
			return
		end

		users = User.find(:all, :conditions => ["level = ?", User::LEVEL_UNACTIVATED])

		users.each do |user|
			if confirmation_hash(user.name) == params["hash"]
				user.update_attribute(:level, User::LEVEL_MEMBER)

				respond_to do |fmt|
					fmt.html {flash[:notice] = "Account has been activated"; redirect_to(:action => "home")}
					fmt.xml {render :xml => {:success => true}.to_xml}
					fmt.js {render :json => {:success => true}.to_json}
				end
				break
			end
		end

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Invalid confirmation code"; redirect_to(:action => "home")}
			fmt.xml {render :xml => {:success => false}.to_xml}
			fmt.js {render :json => {:success => false}.to_json}
		end
	end
end

end
