class UserController < ApplicationController
	layout "default"
	before_filter :user_only, :only => [:favorites, :authenticate, :update]
	verify :method => :post, :only => [:authenticate, :update]

	protected
	def save_cookies(user)
		cookies[:login] = {:value => user.name, :expires => 1.year.from_now}
		cookies[:pass_hash] = {:value => user.password, :expires => 1.year.from_now}
		session[:user_id] = user.id
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
			user = User.create(params[:user])
			if user.errors.empty?
				save_cookies(user)

				respond_to do |fmt|
					fmt.html {flash[:notice] = "New account created"; redirect_to(:action => "home")}
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
		else
			respond_to do |fmt|
				fmt.html {flash[:notice] = "Signups are disabled"; redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => false, :reason => "signups are disabled"}.to_xml, :status => 500}
				fmt.js {render :json => {:success => false, :reason => "signups are disabled"}.to_json, :status => 500}
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

	def index
		set_title "Users"
		@pages, @users = paginate :users, :order => "lower(name)", :per_page => 25
	end

	def update
		user = User.find(params[:id])

		if user.update_attributes(params[:user])
			respond_to do |fmt|
				fmt.html {flash[:notice] = "Account options saved"; redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => true}.to_xml}
				fmt.js {render :json => {:success => true}.to_json}
			end
		else
			error = user.errors.full_messages.join(", ")

			respond_to do |fmt|
				fmt.html {flash[:notice] = "Error: " + h(error); redirect_to(:action => "home")}
				fmt.xml {render :xml => {:success => false, :reason => h(error)}.to_xml, :status => 500}
				fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
			end
		end
	end

	def edit
		set_title "Edit Account"
	end

	def favorites
		@user = User.find(params["id"])

		set_title "#{@user.name}'s Favorites"
		@pages, @posts = paginate :posts, :per_page => 12, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ?", params["id"]], :select => "posts.*"
	end

	def favorites_atom
		@posts = Post.find(:all, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ?", params["id"]], :limit => 24, :select => "posts.*")
		@user = User.find(params["id"])

		render :layout => false
	end
end
