begin
	require 'idn'
rescue LoadError
end

class UserMailer < ActionMailer::Base
	include ActionController::UrlWriter
	default_url_options["host"] = CONFIG["server_host"]

	def confirmation_email(user,hash)
		recipients UserMailer.normalize_address(user.email)
		from CONFIG["admin_contact"]
		subject "#{CONFIG["app_name"]} - Confirm email address"
		body :user => user, :hash => hash
		content_type "text/html"
	end

	def new_password(user, password)
		recipients UserMailer.normalize_address(user.email)
		subject CONFIG["app_name"] + " Password Reset"
		from CONFIG["admin_contact"]
		body :user => user, :password => password
		content_type "text/html"
	end
	
	def self.normalize_address(address)
		if defined?(IDN)
			address =~ /\A([^@]+)@(.+)\Z/
			mailbox = $1
			domain = IDN::Idna.toASCII($2)
			"#{mailbox}@#{domain}"
		else
			address
		end
	end
end
