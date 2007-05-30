require_dependency 'login_system'

class ApplicationController < ActionController::Base
	include LoginSystem
	include ExceptionNotifiable
	local_addresses.clear

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
		prev_tags = cookies["recent_tags"].to_s.gsub(/(?:character|char|ch|copyright|copy|artist):/, "").scan(/\S+/)[0..20].join(" ")
		cookies["recent_tags"] = {:value => (tags + " " + prev_tags), :expires => 1.year.from_now}
	end

	def expire_cache
		$cache_revision += 1
	end

	def cache_if_anonymous
		if @current_user == nil && request.method == :get
			cache_key = url_for(params) + $cache_revision.to_s
			cached = read_fragment(cache_key)
			if cached != nil
				render :text => cached, :layout => false
				return false
			end

			yield

			write_fragment(cache_key, response.body)
		end
	end

	public
	def local_request?
		false
	end
end
