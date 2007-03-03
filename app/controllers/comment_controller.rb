class CommentController < ApplicationController
	layout "default"

	before_filter :user_only, :only => [:add, :list] unless CONFIG["allow_anonymous_comments"]
	before_filter :mod_only, :only => [:moderate]
	verify :method => :post, :only => [:add]

# Creates a new comment.
	def add
		unless params["email"].blank?
			render :nothing => true
			return
		end

		if params["comment"]["body"].scan("http").size > 3
			render :nothing => true
			return
		end

		@comment = Comment.new
		@comment.post_id = params["comment"]["post_id"]
		@comment.user_id = current_user().id rescue nil
		@comment.user_id = nil if params["comment"]["anonymous"] != "1"
		@comment.body = params["comment"]["body"]
		@comment.ip_addr = request.remote_ip

		if @comment.save
			redirect_to :action => "list"
		else
			render_error @comment
		end
	end

	def view
		@comment = Comment.find(params["id"])
		set_title "Comment by #{@comment.author}"
	end

# Show a paginated list of all comments.
	def list
		set_title "Comments"
		@pages, @posts = paginate :posts, :order => "last_commented_at DESC", :conditions => "last_commented_at IS NOT NULL", :per_page => 10
	end

	def moderate
		set_title "Moderate Comments"

		if request.post?
			ids = params["c"].keys
			coms = Comment.find(:all, :conditions => ["id IN (?)", ids])

			if params["commit"] == "Delete"
				coms.each do |c|
					c.destroy
				end
			elsif params["commit"] == "Accept"
				coms.each do |c|
					c.accept!
				end
			end

			redirect_to :action => "moderate"
		else
			@comments = Comment.find(:all, :conditions => "signal_level = 0", :order => "id DESC")
		end
	end
end
