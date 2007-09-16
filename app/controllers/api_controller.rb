class ApiController < ApplicationController
	verify :method => :post, :only => :add_post
  before_filter :privileged_only, :only => :add_post

	def add_post
		unless params["tags"]
			render :text => "incomplete upload", :status => 500
			return
		end

		post_hash = {:file => params["file"], :source => params["source"], :rating => params["rating"], :tags => params["tags"]}
		@post = Post.create(post_hash.merge(:user_id => session[:user_id], :ip_addr => request.remote_ip, :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip))

		if @post.errors.empty?
			if params["md5"] and params["md5"].downcase != @post.md5
				response.headers["X-Danbooru-Errors"] = "mismatched md5"
				render :text => "mismatched md5", :status => 409
				@post.destroy
			else
				response.headers["X-Danbooru-Location"] = url_for(:controller => "post", :action => "show", :id => @post.id)
				render :nothing => true
			end
		elsif @post.errors.invalid?(:md5)
			p = Post.find_by_md5(@post.md5)
			p.update_attributes(:tags => (p.cached_tags.to_s + " " + params["tags"]), :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip)
			response.headers["X-Danbooru-Errors"] = "duplicate"
			response.headers["X-Danbooru-Location"] = url_for(:controller => "post", :action => "show", :id => p.id)
			render :text => "duplicate", :status => 409
		else
			response.headers["X-Danbooru-Errors"] = "other"
			render_error(@post)
		end
	end

	def find_tags
		if params["id"]
			@tags = Tag.find(:all, :conditions => ["id in (?)", params["id"].split(",")])
		elsif params["name"]
			@tags = Tag.find(:all, :conditions => ["name IN (?)", params["name"].split(",")])
		else
			@tags = Tag.find(:all, :conditions => ["post_count > 0 AND id >= ?", params["after_id"] || 0], :order => "id DESC")
		end
	end
end
