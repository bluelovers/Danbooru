class PoolController < ApplicationController
  layout "default"
  before_filter :member_only, :only => [:create, :destroy, :update]
  helper :post
  
  def test
    respond_to do |fmt|
      fmt.js {render :text => "hello"}
    end
  end
  
  def index
    if params[:query]
      @pools = Pool.paginate :order => "updated_at desc", :conditions => ["lower(name) like ?", "%" + params[:query].to_escaped_for_sql_like + "%"], :per_page => 20, :page => params[:page]
    else
      @pools = Pool.paginate :order => "updated_at desc", :per_page => 20, :page => params[:page]
    end
  end
  
  def show
    @pool = Pool.find(params[:id])
    @posts = Post.paginate :per_page => 24, :order => "pools_posts.sequence, pools_posts.post_id", :joins => "JOIN pools_posts ON posts.id = pools_posts.post_id", :conditions => ["pools_posts.pool_id = ?", params[:id]], :select => "posts.*", :page => params[:page]
  end

  def update
    @pool = Pool.find(params[:id])

    unless @current_user.has_permission?(@pool)
      access_denied()
      return
    end

    if request.post?
      @pool.update_attributes(params[:pool])
      redirect_to :action => "show", :id => params[:id]
    end
  end
  
  def create
    if request.post?
      @pool = Pool.create(params[:pool].merge(:user_id => @current_user.id))
      
      if @pool.errors.empty?
        flash[:notice] = "Pool created"
        redirect_to(:action => "index")
      else
        messages = @pool.errors.full_messages.join(", ")
        flash[:notice] = "Error: #{messages}"
        redirect_to(:action => "index")
      end
    else
      @pool = Pool.new(:user_id => @current_user.id)
    end
  end
  
  def destroy
    @pool = Pool.find(params[:id])

    if request.post?
      if @current_user.has_permission?(@pool)
        @pool.destroy
        flash[:notice] = "Pool deleted"
        redirect_to :action => "index"
      else
        flash[:notice] = "Access denied"
        redirect_to :action => "index"
      end
    end
  end
  
  def add_post
    if request.post?
      @pool = Pool.find(params[:pool_id])
      
      if !@pool.is_public? && @current_user.has_permission?(@pool)
        access_denied()
        return
      end
      
      begin
        @pool.add_post(params[:post_id])
        respond_to_success("Post added", :controller => "post", :action => "show", :id => params[:post_id])
      rescue Pool::PostAlreadyExistsError
        respond_to_error("Post already exists", :controller => "post", :action => "show", :id => params[:post_id])
      rescue Exception => x
        respond_to_error(x.class, :controller => "post", :action => "show", :id => params[:post_id])
      end
    else
      if !@current_user.is_anonymous?
        @pools = Pool.find(:all, :order => "name", :conditions => ["is_public = TRUE OR user_id = ?", @current_user.id])
      else
        @pools = Pool.find(:all, :order => "name", :conditions => "is_public = TRUE")
      end
      
      @post = Post.find(params[:post_id])
    end
  end
  
  def remove_post
    if request.post?
      @pool = Pool.find(params[:pool_id])
      
      if !@pool.is_public? && @current_user.has_permission?(@pool)
        access_denied()
        return
      end
      
      @pool.remove_post(params[:post_id])
      response.headers["X-Post-Id"] = params[:post_id]
      respond_to_success("Post removed", :controller => "post", :action => "show", :id => params[:post_id])
    else
      @pool = Pool.find(params[:pool_id])
      @post = Post.find(params[:post_id])
    end
  end
  
  def order
    @pool = Pool.find(params[:id])

    if request.post?
      if @pool.is_public? || @current_user.has_permission?(@pool)
        PoolPost.transaction do
          params[:pool_post_sequence].each do |i, seq|
            PoolPost.update(i, :sequence => seq)
          end
        end
        
        flash[:notice] = "Ordering updated"
      else
        flash[:notice] = "Access denied"
      end

      redirect_to :action => "show", :id => params[:id]
    else
      @pool_posts = PoolPost.find(:all, :conditions => ["pool_id = ?", params[:id]], :order => "sequence, post_id")
    end
  end
  
  def import
    @pool = Pool.find(params[:id])
    
    unless @pool.is_public? || @current_user.has_permission?(@pool)
      access_denied()
      return
    end
    
    if request.post?
      if params[:posts].is_a?(Hash)
        PoolPost.transaction do
          params[:posts].keys.each do |post_id|
            begin
              @pool.add_post(post_id)
            rescue Pool::PostAlreadyExistsError
              # ignore
            end
          end
          
          @pool.update_attribute(:post_count, Post.count_by_sql(["SELECT COUNT(*) FROM pools_posts WHERE pool_id = ?", @pool.id]))
        end
      end
      
      redirect_to :action => "show", :id => @pool.id
    else
      respond_to do |fmt|
        fmt.html
        fmt.js do
          @posts = Post.find_by_tags(params[:query], :order => "id desc", :limit => 500)
          @posts = @posts.select {|x| x.can_view?(@current_user)}
        end
      end
    end
  end
end
