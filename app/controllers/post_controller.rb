class PostController < ApplicationController
	layout 'default'

	before_filter :user_only, :except => [:rss, :atom] unless CONFIG["allow_anonymous_post_access"]
	after_filter :save_tags_to_cookie, :only => [:change]
	helper :wiki, :tag, :comment
	verify :method => :post, :only => [:change]

	def change
		post = Post.find(params["id"])

		post.rating = params["post"]["rating"] if params["post"]["rating"]
		post.source = params["post"]["source"] if params["post"]["source"]

		if post.save
			post.tag! params["post"]["tags"]
			redirect_to :controller => "post", :action => "view", :id => post.id
		else
			render_error(post)
		end
	end

	def remove
		set_title "Remove Post"
		@post = Post.find(params['id'])

		if request.post?
			if current_user().has_permission?(@post)
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

			@post = Post.new
			@post.file = params["post"]["file"]
			@post.source = params["post"]["source"]
			@post.rating = params["post"]["rating"]
			@post.ip_addr = request.remote_ip
			@post.user_id = current_user().id rescue nil

			if @post.save
				@post.tag! params["post"]["tags"]
				post_id = @post.id
			elsif @post.errors.invalid?(:md5)
				p = Post.find_by_md5(@post.md5)
				p.tag!(p.cached_tags + " " + params["post"]["tags"])
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
		@posts = Post.find_by_sql(Post.generate_sql(params["tags"], :limit => 10, :order => "p.id DESC"))
		render :layout => false
	end

	def view
		@post = Post.find(:first, :conditions => ["posts.id = ?", params['id']])
		set_title @post.cached_tags
		@tags = {:include => @post.tags}
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
			@post.tag! @post.tag_history.find(params["history"]).tags
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
