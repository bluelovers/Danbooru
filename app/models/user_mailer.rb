class UserMailer < ActionMailer::Base
	def new_password(user, password)
		recipients user.email
		subject CONFIG["app_name"] + " Password Reset"
		from CONFIG["admin_contact"]
		body :user => user, :password => password
		content_type "text/html"
	end

	def new_invite(user, email, invite)
		recipients email
		subject "You have been invited to #{CONFIG["app_name"]}"
		from CONFIG["invite_contact"]
		body :user => user, :invite => invite
		content_type "text/html"
	end
end
