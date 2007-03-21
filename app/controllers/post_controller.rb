class PostController < ApplicationController
	layout 'default'

	if CONFIG["allow_anonymous_post_access"]
		before_filter :user_only, :only => [:destroy]
	else
		before_filter :user_only
	end

	after_filter :save_tags_to_cookie, :only => [:change, :update]
	helper :wiki, :tag, :comment
	verify :method => :post, :only => [:change, :update, :destroy]

	def create
		if request.post?
			@post = Post.create(params["post"].merge(:updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip, :user_id => session[:user_id], :ip_addr => request.remote_ip))

			if @post.errors.empty?
				respond_to do |fmt|
					fmt.html {flash[:notice] = "Post successfully uploaded"; redirect_to(:controller => "post", :action => "view", :id => @post.id)}
					fmt.xml {render :xml => {:success => true, :location => url_for(:controller => "post", :action => "view", :id => @post.id)}.to_xml(:root => "response")}
					fmt.js {render :json => {:success => true, :location => url_for(:controller => "post", :action => "view", :id => @post.id)}.to_json}
				end
			elsif @post.errors.invalid?(:md5)
				p = Post.find_by_md5(@post.md5)
				p.update_attributes(:tags => (p.cached_tags + " " + params["post"]["tags"]), :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip)
				respond_to do |fmt|
					fmt.html {flash[:notice] = "That post already exists"; redirect_to(:controller => "post", :action => "view", :id => p.id)}
					fmt.xml {render :xml => {:success => true, :location => url_for(:controller => "post", :action => "view", :id => p.id)}.to_xml(:root => "response")}
					fmt.js {render :json => {:success => true, :location => url_for(:controller => "post", :action => "view", :id => p.id)}.to_json}
				end
			else
				respond_to do |fmt|
					fmt.html {render_error(@post)}
					fmt.xml {render :xml => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_xml(:root => "response"), :status => 500}
					fmt.js {render :json => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_json, :status => 500}
				end
			end
		else
			@post = Post.new
		end
	end

	def update
		@post = Post.find(params["id"])

		if @post.update_attributes(params["post"].merge(:updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip))
			respond_to do |fmt|
				fmt.html {flash[:notice] = "Post updated"; redirect_to(:action => "view", :id => @post.id)}
				fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
				fmt.js {render :json > {:success => true}.to_json}
			end
		else
			respond_to do |fmt|
				fmt.html {render_error(@post)}
				fmt.xml {render :xml => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_xml(:root => "response"), :status => 500}
				fmt.js {render :json => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_json, :status => 500}
			end
		end
	end

	def destroy
		@post = Post.find(params["id"])
		if current_user.has_permission?(@post)
			@post.destroy

			respond_to do |fmt|
				fmt.html {flash[:notice] = "Post successfully deleted"; redirect_to(:action => "list")}
				fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
				fmt.js {render :json => {:success => true}.to_json}
			end
		else
			fmt.html {flash[:notice] = "Access denied"; redirect_to(:action => "view", :id => @post.id)}
			fmt.xml {render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 403}
			fmt.js {render :json => {:success => false, :reason => "access denied"}.to_json, :status => 403}
		end
	end

	def change
		post = Post.find(params["id"])

		if post.update_attributes(params["post"].merge(:updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip))
			redirect_to :action => "view", :id => post.id
		else
			render_error(post)
		end
	end

	def remove
		set_title "Remove Post"
		@post = Post.find(params['id'])

		if request.post?
			if (current_user().has_permission?(@post) rescue false)
				@post.destroy
			else
				flash[:notice] = "You have insufficient permission to delete posts"
			end

			redirect_to :action => "list"
		end
	end

	def add
		set_title "Add Post"

		if request.post?
			if current_user() == nil && !CONFIG["allow_anonymous_posts"]
				flash[:notice] = "Anonymous uploads have been disabled"
				redirect_to :action => "list"
				return
			end

			post_id = nil

			if (params["post"]["file"].blank? || params["post"]["file"].size == 0) and params["post"]["source"].blank?
				flash[:notice] = "You must either specify a source URL or upload a file"
				redirect_to :action => "add"
				return
			end

			if params["post"]["source"].nil?
				flash[:notice] = "Incomplete upload, try again"
				redirect_to :action => "add"
				return
			end

			@post = Post.create(params["post"].merge(:user_id => session[:user_id], :ip_addr => request.remote_ip, :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip))

			if @post.errors.empty?
				post_id = @post.id
			elsif @post.errors.invalid?(:md5)
				p = Post.find_by_md5(@post.md5)
				p.update_attributes(:tags => (p.cached_tags + " " + params["post"]["tags"]), :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip)
				post_id = p.id
			else
				render_error(@post)
				return
			end

			save_tags_to_cookie
			redirect_to :action => "view", :id => post_id
		end
	end

	def list
		set_title "Posts: #{params['tags']}"

		@user = current_user()

		if params["tags"]
			@amb_tags = Tag.select_ambiguous(params["tags"])
		else
			@amb_tags = []
		end
		
		@pages = Paginator.new(self, Post.fast_count(params["tags"]), 12, params["page"])
		@posts = Post.find_by_sql(Post.generate_sql(params["tags"], :order => "p.id DESC", :offset => @pages.current.offset, :limit => @pages.items_per_page))

		if params["tags"]
			@tags = Tag.parse_query(params["tags"])
		else
			@tags = {:include => Tag.find(:all, :order => "post_count desc", :limit => 25)}
		end
	end

	def atom
		@posts = Post.find_by_sql(Post.generate_sql(params["tags"], :limit => 24, :order => "p.id DESC"))
		render :layout => false
	end

	def view
		@post = Post.find(:first, :conditions => ["posts.id = ?", params['id']])
		if @post
			set_title @post.cached_tags
			@tags = {:include => @post.tags}
		end
	end

	def popular
		if params["year"] and params["month"] and params["day"]
			@day = Time.gm(params["year"].to_i, params["month"], params["day"])
		else
			@day = Time.new.getgm.at_beginning_of_day
		end

		set_title "Exploring #{@day.year}/#{@day.month}/#{@day.day}"

		@posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at <= ?", @day, @day.tomorrow], :order => "score DESC", :limit => 20, :include => [:user])
	end

	def popular_week
		if params["year"] and params["month"] and params["day"]
			@start = Time.gm(params["year"].to_i, params["month"], params["day"]).beginning_of_week
		else
			@start = Time.new.getgm.beginning_of_week
		end

		@end = @start.next_week

		set_title "Exploring #{@start.year}/#{@start.month}/#{@start.day} - #{@end.year}/#{@end.month}/#{@end.day}"

		@posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
	end

	def popular_month
		if params["year"] and params["month"]
			@start = Time.gm(params["year"].to_i, params["month"], 1)
		else
			@start = Time.new.getgm.beginning_of_month
		end

		@end = @start.next_month

		set_title "Exploring #{@start.year}/#{@start.month}"

		@posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
	end

	def revert_tags
		if request.post?
			@post = Post.find(params["id"])
			@post.update_attributes(:tags => @post.tag_history.find(params["history"]).tags, :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip)
		end

		redirect_to :action => "view", :id => @post.id
	end

	def recent_tag_changes
		@pages, @changes = paginate :post_tag_histories, :order => "id DESC", :per_page => 5
	end

	def tag_history
		@histories = PostTagHistory.find(:all, :conditions => ["post_id = ?", params["id"]], :order => "id")
	end

	def view_favorites
		@post = Post.find(params["id"])
		@users = User.find_people_who_favorited(params["id"])
	end
end
