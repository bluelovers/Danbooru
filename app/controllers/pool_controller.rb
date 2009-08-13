class PoolController < ApplicationController
  layout "default"
  before_filter :member_only, :except => [:index, :show]
  helper :post
  
  def index
    if params[:query]
      query = params[:query].tr(" ", "_").downcase
      @pools = Pool.paginate :order => "updated_at desc", :conditions => ["lower(name) like ?", "%" + query.to_escaped_for_sql_like + "%"], :per_page => 20, :page => params[:page]
    else
      @pools = Pool.paginate :order => "updated_at desc", :per_page => 20, :page => params[:page]
    end
    
    respond_to_list("pools")
  end
  
  def show
    @pool = Pool.find(params[:id])
    @posts = Post.paginate :per_page => 24, :order => "pools_posts.sequence, pools_posts.post_id", :joins => "JOIN pools_posts ON posts.id = pools_posts.post_id", :conditions => ["pools_posts.pool_id = ? AND posts.status <> 'deleted'", params[:id]], :select => "posts.*", :page => params[:page]

    respond_to do |fmt|
      fmt.html
      fmt.xml do
        builder = Builder::XmlMarkup.new(:indent => 2)
        builder.instruct!

        xml = @pool.to_xml(:builder => builder, :skip_instruct => true) do
          builder.posts do
            @posts.each do |post|
              post.to_xml(:builder => builder, :skip_instruct => true)
            end
          end
        end
        render :xml => xml
      end
    end
  end
  
  def show_historical
    @update = PoolUpdate.find(params[:id])
    @pool = @update.pool
    post_ids = @update.post_ids.scan(/(\d+) \d+/).flatten.map(&:to_i)
    @posts = Post.paginate :per_page => 24, :conditions => ["id IN (?)", post_ids], :order => "posts.id", :page => params[:page]
  end

  def update
    @pool = Pool.find(params[:id])

    unless @pool.can_be_updated_by?(@current_user)
      access_denied()
      return
    end

    if request.post?
      @pool.update_attributes(updater_params)
      respond_to_success("Pool updated", :action => "show", :id => params[:id])
    end
  end
  
  def create
    if request.post?
      @pool = Pool.new(updater_params)
      @pool.user_id = @current_user.id
      @pool.save
      
      if @pool.errors.empty?
        respond_to_success("Pool created", :action => "show", :id => @pool.id)
      else
        respond_to_error(@pool, :action => "index")
      end
    else
      @pool = Pool.new(:user_id => @current_user.id, :is_public => true)
    end
  end
  
  def destroy
    @pool = Pool.find(params[:id])

    if request.post?
      if @current_user.has_permission?(@pool)
        @pool.destroy
        respond_to_success("Pool deleted", :action => "index")
      else
        access_denied()
      end
    end
  end
  
  def add_post
    if request.post?
      @pool = Pool.find(params[:pool_id])
      session[:last_pool_id] = @pool.id
      
      if params[:pool] && !params[:pool][:sequence].blank?
        sequence = params[:pool][:sequence]
      else
        sequence = nil
      end
      
      begin
        @pool.updater_user_id = @current_user.id
        @pool.updater_ip_addr = request.remote_ip
        @pool.add_post(params[:post_id], :sequence => sequence, :user => @current_user)
        respond_to_success("Post added", :controller => "post", :action => "show", :id => params[:post_id])
      rescue Pool::PostAlreadyExistsError
        respond_to_error("Post already exists", {:controller => "post", :action => "show", :id => params[:post_id]}, :status => 423)
      rescue Pool::AccessDeniedError
        access_denied()
      rescue Exception => x
        respond_to_error(x.class, :controller => "post", :action => "show", :id => params[:post_id])
      end
    else
      if @current_user.is_anonymous?
        @pools = Pool.find(:all, :order => "name", :conditions => "is_active = TRUE AND is_public = TRUE")
      else
        @pools = Pool.find(:all, :order => "name", :conditions => ["is_active = TRUE AND (is_public = TRUE OR user_id = ?)", @current_user.id])
      end
      
      @post = Post.find(params[:post_id])
    end
  end
  
  def remove_post
    if request.post?
      @pool = Pool.find(params[:pool_id])
      @pool.updater_user_id = @current_user.id
      @pool.updater_ip_addr = request.remote_ip
      
      begin
        @pool.remove_post(params[:post_id], :user => @current_user)
      rescue Pool::AccessDeniedError
        access_denied()
        return
      end
      
      response.headers["X-Post-Id"] = params[:post_id]
      respond_to_success("Post removed", :controller => "post", :action => "show", :id => params[:post_id])
    else
      @pool = Pool.find(params[:pool_id])
      @post = Post.find(params[:post_id])
    end
  end
  
  def order
    @pool = Pool.find(params[:id])
    @pool.updater_user_id = @current_user.id
    @pool.updater_ip_addr = request.remote_ip

    unless @pool.can_be_updated_by?(@current_user)
      access_denied()
      return
    end

    if request.post?
      PoolPost.transaction do
        params[:pool_post_sequence].each do |i, seq|
          PoolPost.update(i, :sequence => seq)
        end
        
        @pool.reload
        @pool.update_pool_links
      end
      
      flash[:notice] = "Ordering updated"
      redirect_to :action => "show", :id => params[:id]
    else
      @pool_posts = PoolPost.find(:all, :conditions => ["pool_id = ?", params[:id]], :order => "sequence, post_id")
    end
  end
  
  def import
    @pool = Pool.find(params[:id])
    @pool.updater_user_id = @current_user.id
    @pool.updater_ip_addr = request.remote_ip
    
    unless @pool.can_be_updated_by?(@current_user)
      access_denied()
      return
    end
    
    if request.post?
      if params[:posts].is_a?(Hash)
        ordered_posts = params[:posts].sort { |a,b| a[1]<=>b[1] }.map { |a| a[0] }

        PoolPost.transaction do
          ordered_posts.each do |post_id|
            begin
              @pool.add_post(post_id, :skip_update_pool_links => true)
            rescue Pool::PostAlreadyExistsError
              # ignore
            end
          end
          @pool.update_pool_links
        end
      end
      
      redirect_to :action => "show", :id => @pool.id
    else
      respond_to do |fmt|
        fmt.html
        fmt.js do
          @posts = Post.find_by_tags(params[:query], :limit => 500)
          @posts = @posts.select {|x| x.can_be_seen_by?(@current_user)}
        end
      end
    end
  end
  
  def select
    if @current_user.is_anonymous?
      @pools = Pool.find(:all, :order => "name", :conditions => "is_active = TRUE AND is_public = TRUE")
    else
      @pools = Pool.find(:all, :order => "name", :conditions => ["is_active = TRUE AND (is_public = TRUE OR user_id = ?)", @current_user.id])
    end
    
    render :layout => false
  end
  
  def history
    @pool = Pool.find(params[:id])
  end
  
  def recent_changes
    @updates = PoolUpdate.paginate :order => "created_at desc", :per_page => 20, :page => params[:page]
  end
  
  def revert
    @update = PoolUpdate.find(params[:id])
    
    if request.post?
      if params[:commit] == "Yes"
        @update.pool.revert_to(@update.id, @current_user.id, request.remote_ip)
        flash[:notice] = "Pool was reverted"
      end
      redirect_to :action => "show", :id => @update.pool_id
    end
  end
  
private
  def updater_params
    params[:pool].merge(:updater_ip_addr => request.remote_ip, :updater_user_id => @current_user.id)
  end
end
