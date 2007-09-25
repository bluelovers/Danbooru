class ForumController < ApplicationController
  layout "default"
  verify :method => :post, :only => [:create, :destroy, :update, :stick, :unstick]
  before_filter :mod_only, :only => [:stick, :unstick]
  before_filter :member_only, :only => [:create, :destroy, :update, :edit, :add]

  def stick
    @forum_post = ForumPost.find(params[:id])
    @forum_post.update_attributes(:is_sticky => true, :last_updated_by => @current_user.id)
    redirect_to :action => "show", :id => params[:id]
  end

  def unstick
    @forum_post = ForumPost.find(params[:id])
    @forum_post.update_attributes(:is_sticky => false, :last_updated_by => @current_user.id)
    redirect_to :action => "show", :id => params[:id]
  end

  def create
    @forum_post = ForumPost.create(params[:forum_post].merge(:creator_id => session[:user_id]))

    if @forum_post.errors.empty?
      if params[:forum_post][:parent_id] == "0"
        flash[:notice] = "Forum thread created"
        redirect_to :action => "show", :id => @forum_post.root_id
      else
        flash[:notice] = "Response posted"
        redirect_to :action => "show", :id => @forum_post.root_id, :page => (@forum_post.root.response_count / 10.0).ceil
      end
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
    @pages, @children = paginate :forum_posts, :order => "id", :per_page => 10, :conditions => ["parent_id = ?", params[:id]]

    if @current_user != nil
      @current_user.update_forum_view(@forum_post.id)
    end
    
    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @forum_post.to_xml(:root => "forum_post")}
      fmt.js {render :json => @forum_post.to_json}
    end
  end

  def index
    if params[:parent_id]
      @pages, @forum_posts = paginate :forum_posts, :order => "is_sticky desc, updated_at DESC", :per_page => 100, :conditions => ["parent_id = ?", params[:parent_id]]
    else
      @pages, @forum_posts = paginate :forum_posts, :order => "is_sticky desc, updated_at DESC", :per_page => 20, :conditions => "parent_id IS NULL"
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @forum_posts.to_xml(:root => "forum_posts")}
      fmt.js {render :json => @forum_posts.to_json}
    end
  end
end
