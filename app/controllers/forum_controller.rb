class ForumController < ApplicationController
	layout "default"
	verify :method => :post, :only => [:create, :destroy, :update]

	if CONFIG["enable_anonymous_forum_access"]
		before_filter :user_only, :only => [:destroy]
	else
		before_filter :user_only, :only => [:create, :destroy, :update, :edit, :add, :show, :index]
	end

	def create
		if CONFIG["enable_anonymous_forum_posts"] == false && @current_user == nil
			access_denied()
			return
		end

		@forum_post = ForumPost.create(params[:forum_post].merge(:creator_id => session[:user_id]))

		if @forum_post.errors.empty?
			if params[:forum_post][:parent_id] == "0"
				flash[:notice] = "Forum thread created"
			else
				flash[:notice] = "Response posted"
			end

			redirect_to :action => "show", :id => @forum_post.root_id
		else
			render_error(@forum_post)
		end
	end

	def add
		@forum_post = ForumPost.new
	end

	def destroy
		@forum_post = ForumPost.find(params[:id])

		if @current_user.has_permission?(@forum_post, :creator_id)
			@forum_post.destroy
			flash[:notice] = "Post destroyed"

			if @forum_post.parent?
				redirect_to :action => "index"
			else
				redirect_to :action => "show", :id => @forum_post.root_id
			end
		else
			flash[:notice] = "Access denied"
			redirect_to :action => "show", :id => @forum_post.root_id
		end
	end

	def update
		@forum_post = ForumPost.find(params[:id])

		if !(@current_user && @current_user.has_permission?(@forum_post, :creator_id))
			access_denied()
			return
		end

		@forum_post.attributes = params[:forum_post]
		if @forum_post.save
			flash[:notice] = "Post updated"
			redirect_to :action => "show", :id => @forum_post.root_id
		else
			render_error(@forum_post)
		end
	end

	def edit
		@forum_post = ForumPost.find(params[:id])

		if !(@current_user && @current_user.has_permission?(@forum_post, :creator_id))
			access_denied()
		end
	end

	def show
		@forum_post = ForumPost.find(params[:id])

		if @current_user != nil
			@current_user.update_forum_view!(@forum_post.id)
		end
	end

	def index
    if params[:parent_id]
      @pages, @forum_posts = paginate :forum_posts, :order => "updated_at DESC", :per_page => 100, :conditions => ["parent_id = ?", params[:parent_id]]
    else
      @pages, @forum_posts = paginate :forum_posts, :order => "updated_at DESC", :per_page => 20, :conditions => "parent_id IS NULL"
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @forum_posts.to_xml}
      fmt.js {render :json => @forum_posts.to_json}
    end
	end
end
