class PostController < ApplicationController
  layout 'default'

  verify :method => :post, :only => [:update, :destroy, :create, :revert_tags, :vote, :flag], :redirect_to => {:action => :show, :id => lambda {|c| c.params[:id]}}
  before_filter :member_only, :only => [:create, :upload, :destroy, :flag, :update]
  before_filter :mod_only, :only => [:moderate]
  after_filter :save_tags_to_cookie, :only => [:update, :create]

  if CONFIG["enable_caching"]
    around_filter :cache_action, :only => [:index, :atom, :show, :piclens]
  end

  helper :wiki, :tag, :comment, :pool, :favorite

  def verify_action(options)
    redirect_to_proc = false
    
    if options[:redirect_to] && options[:redirect_to][:id].is_a?(Proc)
  	  redirect_to_proc = options[:redirect_to][:id]
  	  options[:redirect_to][:id] = options[:redirect_to][:id].call(self)
    end
    
  	result = super(options)
  	
  	if redirect_to_proc
  	  options[:redirect_to][:id] = redirect_to_proc
	  end
	  
	  return result
  end
  
  def create
    if @current_user.is_member_or_lower? && Post.count(:conditions => ["user_id = ? AND created_at > ? ", @current_user.id, 1.day.ago]) >= CONFIG["member_post_limit"]
      respond_to_error("Daily limit exceeded", :action => "index")
      return
    end

    if @current_user.is_privileged_or_higher?
      status = "active"
    else
      status = "pending"
    end

    @post = Post.create(params[:post].merge(:updater_user_id => @current_user.id, :updater_ip_addr => request.remote_ip, :user_id => @current_user.id, :ip_addr => request.remote_ip, :status => status))

    if @post.errors.empty?
      if params[:md5] && @post.md5 != params[:md5].downcase
        @post.destroy
        respond_to_error("MD5 mismatch", :action => "upload")
      else
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Post successfully uploaded"; redirect_to(:controller => "post", :action => "show", :id => @post.id, :tag_title => @post.tag_title)}
          fmt.xml {render :xml => {:success => true, :location => url_for(:controller => "post", :action => "show", :id => @post.id)}.to_xml(:root => "response")}
          fmt.json {render :json => {:success => true, :location => url_for(:controller => "post", :action => "show", :id => @post.id)}.to_json}
        end
      end
    elsif @post.errors.invalid?(:md5)
      p = Post.find_by_md5(@post.md5)

      if p.source.blank? && !@post.source.blank?
        p.update_attributes(:source => @post.source, :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip, :tags => p.cached_tags + " " + params[:post][:tags])
      else
        p.update_attributes(:tags => p.cached_tags + " " + params[:post][:tags], :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip)
      end

      respond_to do |fmt|
        fmt.html {flash[:notice] = "That post already exists"; redirect_to(:controller => "post", :action => "show", :id => p.id, :tag_title => @post.tag_title)}
        fmt.xml {render :xml => {:success => false, :reason => "duplicate", :location => url_for(:controller => "post", :action => "show", :id => p.id)}.to_xml(:root => "response")}
        fmt.json {render :json => {:success => false, :reason => "duplicate", :location => url_for(:controller => "post", :action => "show", :id => p.id)}.to_json}
      end
    else
      respond_to_error(@post, :action => "upload")
    end
  end

  def upload
    @post = Post.new
  end

  def moderate
    if request.post?
      Post.transaction do
        if params[:ids]
          params[:ids].keys.each do |post_id|
            if params[:commit] == "Approve"
              post = Post.find(post_id)
              post.approve!
            elsif params[:commit] == "Delete"
              Post.destroy_with_reason(post_id, params[:reason] || params[:reason2], @current_user)
            end
          end
        end
      end

      redirect_to :action => "moderate"
    else
      if params[:query]
        @pending_posts = Post.find_by_sql(Post.generate_sql(params[:query], :pending => true, :order => "id desc"))
        @flagged_posts = Post.find_by_sql(Post.generate_sql(params[:query], :flagged => true, :order => "id desc"))
      else
        @pending_posts = Post.find(:all, :conditions => "status = 'pending'", :order => "id desc")
        @flagged_posts= Post.find(:all, :conditions => "status = 'flagged'", :order => "id desc")
      end
    end
  end

  def update
    @post = Post.find(params[:id])
    if !@current_user.is_anonymous?
      user_id = @current_user.id
    else
      user_id = nil
    end

    if @post.update_attributes(params[:post].merge(:updater_user_id => user_id, :updater_ip_addr => request.remote_ip))
      respond_to_success("Post updated", :action => "show", :id => @post.id, :tag_title => @post.tag_title)
    else
      respond_to_error(@post, :action => "show", :id => params[:id])
    end
  end

  def destroy
    if params[:commit] == "Cancel"
      redirect_to :action => "show", :id => params[:id]
      return
    end
  
    @post = Post.find(params[:id])

    if @current_user.has_permission?(@post)
      if @post.status == "deleted"
        @post.delete_from_database
      else
        Post.destroy_with_reason(@post.id, params[:reason], @current_user)
      end

      respond_to_success("Post deleted", :action => "index")
    else
      access_denied()
    end
  end
  
  def deleted_index
    if params[:user_id]
      @posts = Post.paginate(:per_page => 25, :order => "flagged_post_details.created_at DESC", :joins => "JOIN flagged_post_details ON flagged_post_details.post_id = posts.id", :select => "flagged_post_details.reason, posts.cached_tags, posts.id, posts.user_id", :conditions => ["posts.status = 'deleted' AND posts.user_id = ?", params[:user_id]], :page => params[:page])
    else
      @posts = Post.paginate(:per_page => 25, :order => "flagged_post_details.created_at DESC", :joins => "JOIN flagged_post_details ON flagged_post_details.post_id = posts.id", :select => "flagged_post_details.reason, posts.cached_tags, posts.id, posts.user_id", :conditions => ["posts.status = 'deleted'"], :page => params[:page])
    end
  end

  def index
    tags = params[:tags].to_s
    split_tags = tags.scan(/\S+/)
    page = params[:page].to_i
    limit = params[:limit].to_i
    limit = 16 if limit == 0
    limit = 1000 if limit > 1000
    count = 0
    begin
      count = Post.fast_count(tags)
    rescue => x
      flash[:notice] = "Error: #{x}"
      redirect_to :action => "index"
      return
    end

    set_title "/" + tags.tr("_", " ")

    if @current_user.is_anonymous? && CONFIG["show_only_first_page"] && page > 1
      flash[:notice] = "You need an account to look beyond the first page."
      redirect_to :controller => "user", :action => "login"
      return
    end

    @ambiguous = Tag.select_ambiguous(tags)
    
    @posts = WillPaginate::Collection.create(page, limit, count) do |pager|
      pager.replace(Post.find_by_sql(Post.generate_sql(tags, :order => "p.id DESC", :offset => pager.offset, :limit => pager.per_page)))
    end

    respond_to do |fmt|
      fmt.html do        
        if split_tags.any?
          @tags = Tag.parse_query(tags)
        elsif CONFIG["enable_caching"]
          @tags = Cache.get("$poptags", 1.hour) do
            {:include => Tag.count_by_period(1.day.ago, Time.now, :limit => 25)}
          end
        else
          @tags = {:include => Tag.count_by_period(1.day.ago, Time.now, :limit => 25)}
        end
      end
      fmt.xml do
        builder = Builder::XmlMarkup.new(:indent => 2)
        builder.instruct!
        
        xml = builder.posts(:count => count, :offset => (limit * (page - 1))) do
          @posts.each do |post|
            post.to_xml(:builder => builder, :skip_instruct => true, :root => "post")
          end
        end
        render :xml => xml
      end
      fmt.json {render :json => @posts.to_json}
    end
  end

  def atom
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :limit => 24, :order => "p.id DESC"))
    headers["Content-Type"] = "application/atom+xml"
    render :layout => false
  end

  def piclens
    @posts = WillPaginate::Collection.create(params[:page], 16, Post.fast_count(params[:tags])) do |pager|
      pager.replace(Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC", :offset => pager.offset, :limit => pager.per_page)))
    end
    
    headers["Content-Type"] = "application/rss+xml"
    render :layout => false
  end

  def show
    begin
      if params[:md5]
        @post = Post.find_by_md5(params[:md5].downcase)
        if @post.nil?
          raise ActiveRecord::RecordNotFound
        end
      else
        @post = Post.find(params[:id])
      end
      
      @favorited_by = @post.favorited_by
      @pools = Pool.find(:all, :joins => "JOIN pools_posts ON pools_posts.pool_id = pools.id", :conditions => "pools_posts.post_id = #{@post.id}", :order => "pools.name", :select => "pools.name, pools.id")
      @tags = {:include => @post.cached_tags.split(/ /)}
      set_title @post.cached_tags.tr("_", " ")
    rescue ActiveRecord::RecordNotFound
      render :status => 404
    end
  end

  def popular_by_day
    if params[:year] && params[:month] && params[:day]
      @day = Time.gm(params[:year].to_i, params[:month], params[:day])
    else
      @day = Time.new.getgm.at_beginning_of_day
    end

    set_title "Exploring #{@day.year}/#{@day.month}/#{@day.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at <= ? ", @day, @day.tomorrow], :order => "score DESC", :limit => 20, :include => [:user])

    respond_to_list("posts")
  end

  def popular_by_week
    if params[:year] && params[:month] && params[:day]
      @start = Time.gm(params[:year].to_i, params[:month], params[:day]).beginning_of_week
    else
      @start = Time.new.getgm.beginning_of_week
    end

    @end = @start.next_week

    set_title "Exploring #{@start.year}/#{@start.month}/#{@start.day} - #{@end.year}/#{@end.month}/#{@end.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])

    respond_to_list("posts")
  end

  def popular_by_month
    if params[:year] && params[:month]
      @start = Time.gm(params[:year].to_i, params[:month], 1)
    else
      @start = Time.new.getgm.beginning_of_month
    end

    @end = @start.next_month

    set_title "Exploring #{@start.year}/#{@start.month}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])

    respond_to_list("posts")
  end

  def revert_tags
    user_id = @current_user.id rescue nil
    @post = Post.find(params[:id])
    @post.update_attributes(:tags => @post.tag_history.find(params[:history_id].to_i).tags, :updater_user_id => user_id, :updater_ip_addr => request.remote_ip)

    respond_to_success("Tags reverted", :action => "show", :id => @post.id, :tag_title => @post.tag_title)
  end

  def favorites
    set_title "Users who favorited this post"
    @post = Post.find(params["id"])
    @users = User.find_people_who_favorited(params["id"])

    respond_to_list("users")
  end

  def vote
    p = Post.find(params[:id])
    score = params[:score].to_i
    
    if !@current_user.is_mod_or_higher? && score != 1 && score != -1
      respond_to_error("Invalid score", :action => "show", :id => params[:id], :tag_title => p.tag_title)
      return
    end

    if p.vote!(score, request.remote_ip)
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Vote saved" ; redirect_to(:action => "show", :id => params[:id], :tag_title => p.tag_title)}
        fmt.json {render :json => {:success => true, :score => p.score, :post_id => p.id}.to_json}
        fmt.xml {render :xml => {:success => true, :score => p.score, :post_id => p.id}.to_xml(:root => "response")}
      end
    else
      respond_to_error("Already voted", :action => "show", :id => params[:id], :tag_title => p.tag_title)
    end
  end

  def delete
    @post = Post.find(params[:id])
  end
  
  def flag
    Post.find(params[:id]).flag!(params[:reason], @current_user.id)
    respond_to_success("Post flagged", :action => "show", :id => params{:id})
  end
  
  def random
    max_id = Post.maximum(:id)
    
    10.times do
      post = Post.find(:first, :conditions => ["id = ? AND status <> 'deleted'", rand(max_id) + 1], :select => "id, cached_tags")

      if post != nil
        redirect_to :action => "show", :id => post.id, :tag_title => post.tag_title
        return
      end
    end
    
    flash[:notice] = "Couldn't find a post in 10 tries. Try again."
    redirect_to :action => "index"
  end
end
