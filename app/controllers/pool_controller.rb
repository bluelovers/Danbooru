class PoolController < ApplicationController
  layout "default"
  before_filter :member_only, :only => [:create, :destroy, :update]
  helper :post
  
  def index
    if params[:query]
      @pages, @pools = paginate :pools, :order => "updated_at desc", :conditions => ["lower(name) like ?", "%" + params[:query].to_escaped_for_sql_like + "%"], :per_page => 20
    else
      @pages, @pools = paginate :pools, :order => "updated_at desc", :per_page => 20
    end
  end
  
  def show
    @pool = Pool.find(params[:id])
    @pages, @posts = paginate :posts, :per_page => 24, :order => "pools_posts.sequence, pools_posts.post_id", :joins => "JOIN pools_posts ON posts.id = pools_posts.post_id", :conditions => ["pools_posts.pool_id = ?", params[:id]], :select => "posts.*"
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
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Access denied"; redirect_to(:controller => "post", :action => "show", :id => params[:post_id])}
          fmt.xml {render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 401}
          fmt.js {render :json => {:success => false, :reason => "access denied"}.to_json, :status => 401}
        end
        
        return
      end
      
      begin
        @pool.add_post(params[:post_id])
        
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Post added to pool"; redirect_to(:controller => "post", :action => "show", :id => params[:post_id])}
          fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
          fmt.js {render :json => {:success => true}.to_json}
        end
      rescue Pool::PostAlreadyExistsError
        respond_to do |fmt|
          fmt.html {flash[:notice] = "That post already exists in the pool"; redirect_to(:controller => "post", :action => "show", :id => params[:post_id])}
          fmt.xml {render :xml => {:success => false, :reason => "already exists"}.to_xml(:root => "response"), :status => 409}
          fmt.js {render :json => {:success => false, :reason => "already exists"}.to_json, :status => 409}
        end
      rescue Exception => x
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Error"; redirect_to(:controller => "post", :action => "show", :id => params[:post_id])}
          fmt.xml {render :xml => {:success => false, :reason => "error: #{x.class}"}.to_xml(:root => "response"), :status => 500}
          fmt.js {render :json => {:success => false, :reason => "error: #{x.class}"}.to_json, :status => 500}
        end
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
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Access denied"; redirect_to(:controller => "post", :action => "show", :id => params[:post_id])}
          fmt.xml {render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 401}
          fmt.js {render :json => {:success => false, :reason => "access denied"}.to_json, :status => 401}
        end
        
        return
      end
      
      @pool.remove_post(params[:post_id])
      response.headers["X-Post-Id"] = params[:post_id]
      
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post removed from pool"; redirect_to(:controller => "post", :action => "show", :id => params[:post_id])}
        fmt.xml {render :xml => {:success => true, :post_id => params[:post_id]}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true, :post_id => params[:post_id]}.to_json}
      end
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
          render :action => "import.rjs"
        end
      end
    end
  end
end
