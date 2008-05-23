begin
  require 'idn'
rescue LoadError
end

class UserMailer < ActionMailer::Base
  include ActionController::UrlWriter
  helper :application
  default_url_options["host"] = CONFIG["server_host"]

  def confirmation_email(user)
    recipients UserMailer.normalize_address(user.email)
    from CONFIG["admin_contact"]
    subject "#{CONFIG["app_name"]} - Confirm email address"
    body :user => user
    content_type "text/html"
  end

  def new_password(user, password)
    recipients UserMailer.normalize_address(user.email)
    subject "#{CONFIG["app_name"]} - Password Reset"
    from CONFIG["admin_contact"]
    body :user => user, :password => password
    content_type "text/html"
  end
  
  def dmail(recipient, sender, msg_title, msg_body)
    recipients UserMailer.normalize_address(recipient.email)
    subject "#{CONFIG["app_name"]} - Message received from #{sender.name}"
    from CONFIG["admin_contact"]
    body :recipient => recipient, :sender => sender, :title => msg_title, :body => msg_body
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
