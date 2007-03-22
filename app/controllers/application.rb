require_dependency 'login_system'

class ApplicationController < ActionController::Base
	include LoginSystem

	before_filter :set_title
	before_filter :current_user

	protected
	def api_request?
		@is_api_request == true
	end

	def render_error(record)
		@record = record
		render :status => 500, :layout => "bare", :inline => "<%= error_messages_for('record') %>"
	end

	def set_title(title = CONFIG["app_name"])
		@page_title = title
	end

	def save_tags_to_cookie
		tags = params["tags"] || params["post"]["tags"]
		cookies["recent_tags"] = {:value => (tags + " " + cookies["recent_tags"].to_s).split(" ")[0..20].join(" "), :expires => 1.year.from_now}
	end

	public
	def local_request?
		false
	end

	def rescue_action_in_public(e)
		render :layout => "bare", :status => 500, :text => "<h6>Exception: #{e}</h6><pre>" + e.backtrace.reject {|i| i =~ /ruby/}.join("\n") + "</pre>"
	end
end
