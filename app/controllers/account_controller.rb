class AccountController < ApplicationController
	layout "default"
	before_filter :user_only, :only => [:change_password]

	protected
	def save_cookies(user)
		cookies[:login] = {:value => user.name, :expires => 1.year.from_now}
		cookies[:pass_hash] = {:value => user.password, :expires => 1.year.from_now}
		session[:user_id] = user.id
	end

	public
	def index
		set_title "My Account"
	end

	def login
		set_title "Login"

		if request.post?
			if user = User.authenticate(params["user"]["name"], params["user"]["password"])
				save_cookies(user)
				user.increment!(:login_count)
				flash[:notice] = "Successfully logged in"
				redirect_to :action => "index"
			end
		end
	end

	def signup
		set_title "Signup"

		if request.post?
			if user = User.create(params[:user])
				save_cookies(user)
				flash[:notice] = "New account created"
				redirect_to :action => "index"
			else
				render_error(user)
			end
		end
	end

	def logout
		set_title "Logout"
		session[:user_id] = nil
		redirect_to :action => "index"
	end

	def list
		set_title "Users"
		@pages, @users = paginate :users, :order => "lower(name)", :per_page => 25
	end

	def change_password
		set_title "Change Password"
		user = current_user()

		if request.post?
			if user.update_attributes(params["user"])
				save_cookies(user)
				flash[:notice] = "Password changed"
				redirect_to :action => "index"
			else
				render_error(@user)
			end
		end
	end

	def options
		set_title "Account Options"
	end

	def favorites
		set_title "My Favorites"
		@pages, @posts = paginate :posts, :per_page => 12, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ?", params["id"]], :select => "posts.*"
		@user = User.find(params["id"])
	end

	def favorites_atom
		@posts = Post.find(:all, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ?", params["id"]], :limit => 24, :select => "posts.*")
		@user = User.find(params["id"])

		render :layout => false
	end
end
