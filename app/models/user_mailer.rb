class UserMailer < ActionMailer::Base
	def new_password(user, password)
		recipients user.email
		subject CONFIG["app_name"] + " Password Reset"
		from CONFIG["admin_contact"]
		body :user => user, :password => password
		content_type "text/html"
	end
end
