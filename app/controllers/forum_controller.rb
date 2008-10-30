class ForumController < ApplicationController
  layout "default"
  verify :method => :post, :only => [:create, :destroy, :update, :stick, :unstick, :lock, :unlock]
  before_filter :mod_only, :only => [:stick, :unstick, :lock, :unlock]
  before_filter :member_only, :only => [:create, :destroy, :update, :edit, :add, :mark_all_read]

  def stick
    ForumPost.stick!(params[:id])
    flash[:notice] = "Topic stickied"
    redirect_to :action => "show", :id => params[:id]
  end

  def unstick
    ForumPost.unstick!(params[:id])
    flash[:notice] = "Topic unstickied"
    redirect_to :action => "show", :id => params[:id]
  end

  def preview
    render :inline => "<h4>Preview</h4><%= format_text(params[:forum_post][:body]) %>"
  end

  def create
    @forum_post = ForumPost.create(params[:forum_post].merge(:creator_id => session[:user_id]))

    if @forum_post.errors.empty?
      if params[:forum_post][:parent_id].to_i == 0
        flash[:notice] = "Forum topic created"
        redirect_to :action => "show", :id => @forum_post.root_id
      else
        flash[:notice] = "Response posted"
        redirect_to :action => "show", :id => @forum_post.root_id, :page => (@forum_post.root.response_count / 10.0).ceil
      end
    else
      render_error(@forum_post)
    end
  end

  def destroy
    @forum_post = ForumPost.find(params[:id])

    if @current_user.has_permission?(@forum_post, :creator_id)
      @forum_post.destroy
      flash[:notice] = "Post destroyed"

      if @forum_post.is_parent?
        redirect_to :action => "index"
      else
        redirect_to :action => "show", :id => @forum_post.root_id
      end
    else
      flash[:notice] = "Access denied"
      redirect_to :action => "show", :id => @forum_post.root_id
    end
  end

  def edit
    @forum_post = ForumPost.find(params[:id])

    if !@current_user.has_permission?(@forum_post, :creator_id)
      access_denied()
    end
  end

  def update
    @forum_post = ForumPost.find(params[:id])

    if !@current_user.has_permission?(@forum_post, :creator_id)
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

  def show
    @forum_post = ForumPost.find(params[:id])
    set_title @forum_post.title
    @children = ForumPost.paginate :order => "id", :per_page => 10, :conditions => ["parent_id = ?", params[:id]], :page => params[:page]

    if !@current_user.is_anonymous? && @current_user.last_forum_topic_read_at < @forum_post.updated_at && @forum_post.updated_at < 3.seconds.ago
      @current_user.update_attribute(:last_forum_topic_read_at, @forum_post.updated_at)
    end
    
    respond_to_list("forum_post")
  end

  def index
    set_title CONFIG["app_name"] + " Forum"
  
    if params[:parent_id]
      @forum_posts = ForumPost.paginate :order => "is_sticky desc, updated_at DESC", :per_page => 100, :conditions => ["parent_id = ?", params[:parent_id]], :page => params[:page]
    else
      @forum_posts = ForumPost.paginate :order => "is_sticky desc, updated_at DESC", :per_page => 20, :conditions => "parent_id IS NULL", :page => params[:page]
    end

    respond_to_list("forum_posts")
  end
  
  def search
    if params[:query]
      query = params[:query].scan(/\S+/).join(" & ")
      @forum_posts = ForumPost.paginate :order => "id desc", :per_page => 25, :conditions => ["text_search_index @@ plainto_tsquery(?)", query], :page => params[:page]
    else
      @forum_posts = ForumPost.paginate :order => "id desc", :per_page => 25, :page => params[:page]
    end
    
    respond_to_list("forum_posts")
  end

  def lock
    ForumPost.lock!(params[:id])
    flash[:notice] = "Topic locked"
    redirect_to :action => "show", :id => params[:id]    
  end

  def unlock
    ForumPost.unlock!(params[:id])
    flash[:notice] = "Topic unlocked"
    redirect_to :action => "show", :id => params[:id]    
  end
  
  def mark_all_read
    @current_user.update_attribute(:last_forum_topic_read_at, Time.now)
    render :nothing => true
  end
end
