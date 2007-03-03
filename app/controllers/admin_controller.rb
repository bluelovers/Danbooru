class AdminController < ApplicationController
	layout "default"
	before_filter :admin_only

	def index
		set_title "Admin"
	end

	def settings
		set_title "Settings"

		if request.post?
			params["settings"].each do |k, v|
				CONFIG[k] = v
			end

			CONFIG.save!

			redirect_to :action => "index"
		end
	end

	def edit_account
		set_title = "Edit Account"

		if request.post?
			@user = User.find(params["user"]["id"])
			@user.level = params["user"]["level"]
			@user.password = params["user"]["password"]
			@user.password_confirmation = params["user"]["password_confirmation"]

			if @user.save
				redirect_to :action => "edit_account"
			else
				render_error(@user)
			end
		end
	end

	def reset_pass
		set_title "Reset password"

		if request.post?
			u = User.find_by_name(params["name"])

			if u
				pass = u.reset_pass!
				flash[:notice] = "Password for " + params["name"] + " reset to: " + pass
				redirect_to :action => "index"
			else
				flash[:notice] = "User " + params["name"] + " not found."
				redirect_to :action => "reset_pass"
			end
		end
	end
end
