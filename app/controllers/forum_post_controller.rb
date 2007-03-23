class ForumPostController < ApplicationController
	layout "default"
	before_filter :user_only

	def create
		@forum_post = ForumPost.create(params["forum_post"].merge(:user_id => session[:user_id]))

		if @forum_post.errors.empty?
			if params["forum_post"]["parent_id"] == "0"
				flash[:notice] = "Forum thread created"
			else
				flash[:notice] = "Response posted"
			end

			redirect_to :action => "view", :id => @forum_post.view_id
		else
			render_error(@forum_post)
		end
	end

	def add
		@forum_post = ForumPost.new
	end

	def destroy
		if request.post?
			@forum_post = ForumPost.find(params["id"])
			if session[:user].has_permission?(@forum_post, :creator_id)
				@forum_post.destroy
				flash[:notice] = "Post destroyed"

				if @forum_post.parent?
					redirect_to :action => "list"
				else
					redirect_to :action => "view", :id => @forum_post.view_id
				end
			else
				flash[:notice] = "Access denied"
				redirect_to :action => "view", :id => @forum_post.view_id
			end
		end
	end

	def update
		@forum_post = ForumPost.find(params["id"])

		if !session[:user].has_permission?(@forum_post, :creator_id)
			flash[:notice] = "Access denied"
			redirect_to :action => "view", :id => @forum_post.view_id
			return
		end

		if request.post?
			@forum_post.attributes = params["forum_post"]
			if @forum_post.save
				flash[:notice] = "Post updated"
				redirect_to :action => "view", :id => @forum_post.view_id
			else
				render_error(@forum_post)
			end
		end
	end

	def view
		@forum_post = ForumPost.find(params["id"])
	end

	def list
		@pages, @forum_posts = paginate :forum_posts, :order => "updated_at DESC", :per_page => 20
	end
end
