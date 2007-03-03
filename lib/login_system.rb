require_dependency "user"

module LoginSystem
	protected
	def access_denied
		if api_request?
			render :text => "Access denied", :status => 403
		else
			flash["notice"] = "Access denied"
			redirect_to :controller => "account", :action => "login"
		end
	end

	def current_user
		user = nil

		if session[:user_id]
			user = User.find(session[:user_id])
		elsif cookies["login"] && cookies["pass_hash"]
			user = User.authenticate_hash(cookies["login"], cookies["pass_hash"])
		elsif params["login"] && params["password"]
			user = User.authenticate(params["login"], params["password"])
		end

		if user
			session[:user_id] = user.id
		end

		return user
	end

	def mod_only
		if (current_user.role?(:mod) rescue false)
			return true
		else
			access_denied
			return false
		end
	end

	def admin_only
		if (current_user.role?(:admin) rescue false)
			return true
		else
			access_denied
			return false
		end
	end

	def user_only
		if (current_user.role?(:member) rescue false)
			return true
		else
			access_denied
			return false
		end
	end

	def user_only_api
		if (current_user.role?(:member) rescue false)
			return true
		else
			render :text => "Only registered users can use this feature", :status => 403
			return false
		end
	end

# Automates authentication of users
	def authenticate
		user = session[:user]
		user = User.authenticate_hash(cookies["login"], cookies["pass_hash"]) if user.nil? && cookies["pass_hash"]
		user = User.authenticate(params["login"], params["password"]) if user.nil? && params["password"]
		user
	end
end
