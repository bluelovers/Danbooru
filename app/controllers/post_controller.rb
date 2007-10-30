class PostController < ApplicationController
  layout 'default'

  verify :method => :post, :only => [:update, :destroy, :create, :revert_tags, :vote, :flag]
  before_filter :member_only, :only => [:create, :upload, :destroy, :flag, :update]
  before_filter :mod_only, :only => [:moderate]
  after_filter :save_tags_to_cookie, :only => [:update, :create]

  if CONFIG["enable_caching"]
    around_filter :cache_action, :only => [:index, :atom]
  end

  helper :wiki, :tag, :comment, :pool, :favorite

  def create
    if @current_user.level == User::LEVEL_MEMBER && Post.count(:conditions => ["user_id = ? AND created_at > ?", @current_user.id, 1.day.ago]) >= CONFIG["member_post_limit"]
      respond_to do |fmt|
        fmt.html {flash[:notice] = "You cannot upload more than #{CONFIG['member_post_limit']} posts in a day"; redirect_to(:action => "upload")}
        fmt.xml {render :xml => {:success => false, :reason => "daily limit exceeded"}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :json => {:success => false, :reason => "daily limit exceeded"}.to_json, :status => 500}
      end

      return
    end

    @post = Post.create(params[:post].merge(:updater_user_id => @current_user.id, :updater_ip_addr => request.remote_ip, :user_id => @current_user.id, :ip_addr => request.remote_ip, :is_pending => !@current_user.privileged?))

    if @post.errors.empty?
      if params[:md5] && @post.md5 != params[:md5].downcase
        @post.destroy
        respond_to do |fmt|
          fmt.html {flash[:notice] = "MD5 mismatch"; redirect_to(:controller => "post", :action => "index")}
          fmt.xml {render :xml => {:success => false, :reason => "md5 mismatch"}.to_xml(:root => "response")}
          fmt.js {render :json => {:success => false, :reason => "md5 mismatch"}.to_json}
        end
      else
        respond_to do |fmt|
          fmt.html do
            flash[:notice] = "Post successfully uploaded"
            redirect_to(:controller => "post", :action => "show", :id => @post.id)
          end
          fmt.xml {render :xml => {:success => true, :location => url_for(:controller => "post", :action => "show", :id => @post.id)}.to_xml(:root => "response")}
          fmt.js {render :json => {:success => true, :location => url_for(:controller => "post", :action => "show", :id => @post.id)}.to_json}
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
        fmt.html do
          flash[:notice] = "That post already exists"
          redirect_to(:controller => "post", :action => "show", :id => p.id)
        end
        fmt.xml {render :xml => {:success => false, :reason => "duplicate", :location => url_for(:controller => "post", :action => "show", :id => p.id)}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => false, :reason => "duplicate", :location => url_for(:controller => "post", :action => "show", :id => p.id)}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {render_error(@post)}
        fmt.xml {render :xml => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :json => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_json, :status => 500}
      end
    end
  end

  def upload
    @post = Post.new
  end

  def moderate
    if request.post?
      Post.transaction do
        params[:ids].keys.each do |post_id|
          if params[:commit] == "Unflag"
            FlaggedPost.unflag(post_id)
          elsif params[:commit] == "Delete"
            FlaggedPost.flag(post_id, params[:reason], true)
            Post.destroy(post_id)
          elsif params[:commit] == "Approve"
            Post.update(post_id, :is_pending => false)
          end
        end
      end

      redirect_to :action => "moderate"
    else
      if params[:query]
        @posts = Post.find_by_sql(Post.generate_sql(params[:query], :pending => true, :order => "id desc"))
      else
        @posts = Post.find(:all, :conditions => "id in (select post_id from flagged_posts where is_resolved = false) OR is_pending = TRUE", :order => "id desc")
      end
    end
  end

  def update
    @post = Post.find(params[:id])
    if @current_user
      user_id = @current_user.id
    else
      user_id = nil
    end

    # Make sure this gets assigned first in case we want to change this and change the post's rating at once.
    @post.is_rating_locked = params[:post][:is_rating_locked] if params[:post][:is_rating_locked]

    if @post.update_attributes(params[:post].merge(:updater_user_id => user_id, :updater_ip_addr => request.remote_ip))
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post updated"; redirect_to(:action => "show", :id => @post.id)}
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {render_error(@post)}
        fmt.xml {render :xml => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :json => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_json, :status => 500}
      end
    end
  end

  def destroy
    if params[:commit] == "Cancel"
      redirect_to :action => "show", :id => params[:id]
      return
    end
  
    @post = Post.find(params[:id])

    unless params[:reason].blank?
      FlaggedPost.flag(params[:id], params[:reason])
    end

    if @current_user.has_permission?(@post)
      @post.destroy
    end
    
    respond_to do |fmt|
      fmt.html {flash[:notice] = "Post deleted"; redirect_to(:action => "index")}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
      fmt.js {render :json => {:success => true}.to_json}
    end
  end

  def index
    set_title ERB::Util.h("/#{params[:tags]}")

    if @current_user == nil && params[:tags].to_s.include?(" ")
      flash[:notice] = "You must be logged in to search for more than one tag at a time."
      redirect_to :controller => "user", :action => "login"
      return
    end

    limit = params[:limit].to_i
    if limit == 0 || limit > 100
      limit = 16
    end

    @ambiguous = Tag.select_ambiguous(params[:tags])
    @pages = Paginator.new(self, Post.fast_count(params[:tags], hide_unsafe_posts?), limit, params[:page])
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC", :offset => @pages.current.offset, :limit => @pages.items_per_page, :hide_unsafe_posts => hide_unsafe_posts?))

    if @posts.empty? && !params[:tags].blank?
      @suggestions = Tag.find(:all, :select => "name", :conditions => ["name LIKE ? ESCAPE '\\\\'", "%" + params[:tags].to_escaped_for_sql_like + "%"], :order => "name", :limit => 10).map {|x| x.name}
    else
      @suggestions = []
    end

    respond_to do |fmt|
      fmt.html do        
        if params[:tags]
          @tags = Tag.parse_query(params[:tags])
        else
          if CONFIG["enable_caching"]
            @tags = Cache.get("poptags:#{hide_unsafe_posts?}", 60) do
              {:include => Tag.count_by_period(3.days.ago, Time.now, :limit => 25, :hide_unsafe_posts => hide_unsafe_posts?)}
            end
          else
            @tags = {:include => Tag.count_by_period(3.days.ago, Time.now, :limit => 25, :hide_unsafe_posts => hide_unsafe_posts?)}
          end
        end
      end
      fmt.xml {render :xml => @posts.to_xml(:root => "posts")}
      fmt.js {render :json => @posts.to_json}
    end
  end

  def atom
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :limit => 24, :order => "p.id DESC", :hide_unsafe_posts => hide_unsafe_posts?))
    render :layout => false
  end

  def show
    begin
      @post = Post.find(params[:id].to_i)
      @pools = Pool.find(:all, :joins => "JOIN pools_posts ON pools_posts.pool_id = pools.id", :conditions => "pools_posts.post_id = #{@post.id}", :order => "pools.name", :select => "pools.name, pools.id")
      @tags = {:include => @post.cached_tags.split(/ /)}
      set_title ERB::Util.h(@post.cached_tags)
    rescue ActiveRecord::RecordNotFound
      @flagged_post = FlaggedPost.find_by_post_id(params[:id])
      flash.now[:notice] = "That post ID was not found" unless @flagged_post
    end
  end

  def popular_by_day
    if params[:year] && params[:month] && params[:day]
      @day = Time.gm(params[:year].to_i, params[:month], params[:day])
    else
      @day = Time.new.getgm.at_beginning_of_day
    end

    set_title "Exploring #{@day.year}/#{@day.month}/#{@day.day}"

    if @current_user && @current_user.privileged?
      @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at <= ?", @day, @day.tomorrow], :order => "score DESC", :limit => 20, :include => [:user])
    else
      @posts = Post.find(:all, :conditions => ["posts.rating = 's' AND posts.is_pending = FALSE AND posts.created_at >= ? AND posts.created_at <= ?", @day, @day.tomorrow], :order => "score DESC", :limit => 20, :include => [:user])
    end
    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.to_xml(:root => "posts")}
      fmt.js {render :json => @posts.to_json}
    end
  end

  def popular_by_week
    if params[:year] && params[:month] && params[:day]
      @start = Time.gm(params[:year].to_i, params[:month], params[:day]).beginning_of_week
    else
      @start = Time.new.getgm.beginning_of_week
    end

    @end = @start.next_week

    set_title "Exploring #{@start.year}/#{@start.month}/#{@start.day} - #{@end.year}/#{@end.month}/#{@end.day}"

    if @current_user && @current_user.privileged?
      @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
    else
      @posts = Post.find(:all, :conditions => ["posts.rating = 's' AND posts.is_pending = FALSE AND posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.to_xml(:root => "posts")}
      fmt.js {render :json => @posts.to_json}
    end
  end

  def popular_by_month
    if params[:year] && params[:month]
      @start = Time.gm(params[:year].to_i, params[:month], 1)
    else
      @start = Time.new.getgm.beginning_of_month
    end

    @end = @start.next_month

    set_title "Exploring #{@start.year}/#{@start.month}"

    if @current_user && @current_user.privileged?
      @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
    else
      @posts = Post.find(:all, :conditions => ["posts.rating = 's' AND posts.is_pending = FALSE AND posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.to_xml(:root => "posts")}
      fmt.js {render :json => @posts.to_json}
    end
  end

  def revert_tags
    user_id = @current_user.id rescue nil
    @post = Post.find(params[:id])
    @post.update_attributes(:tags => @post.tag_history.find(params[:history_id].to_i).tags, :updater_user_id => user_id, :updater_ip_addr => request.remote_ip)

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Tags reverted"; redirect_to(:action => "show", :id => @post.id)}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
      fmt.js {render :json => {:success => true}.to_json}
    end
  end

  def tag_history
    set_title "Tag History"

    params[:limit] ||= 100
    params[:limit] = params[:limit].to_i

    if params[:post_id]
      conditions = ["post_id = ?", params[:post_id]]
    else
      conditions = nil
    end

    respond_to do |fmt|
      fmt.html {@pages, @changes = paginate :post_tag_histories, :order => "id DESC", :per_page => params[:limit], :conditions => conditions}
      fmt.xml {render :xml => PostTagHistory.find(:all, :limit => params[:limit], :offset => params[:offset], :order => "id DESC", :conditions => conditions).to_xml(:root => "posts")}
      fmt.js {render :json => PostTagHistory.find(:all, :limit => params[:limit], :offset => params[:offset], :order => "id DESC", :conditions => conditions).to_json}
    end
  end

  def favorites
    set_title "Users who favorited this post"
    @post = Post.find(params["id"])
    @users = User.find_people_who_favorited(params["id"])

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @users.to_xml(:root => "users")}
      fmt.js {render :json => @users.to_json}
    end
  end

  def vote
    p = Post.find(params[:id])
    score = params[:score].to_i

    unless score == 1 || score == -1
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Invalid score"; redirect_to(:action => "show", :id => params[:id])}
        fmt.xml {render :xml => {:success => false, :reason => "invalid score"}.to_xml(:root => "response"), :status => 409}
        fmt.js {render :json => {:success => false, :reason => "invalid score"}.to_json, :status => 409}
      end
      return
    end

    if p.vote!(score, request.remote_ip)
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Vote saved"; redirect_to(:action => "show", :id => params[:id])}
        fmt.xml {render :xml => {:success => true, :score => p.score, :post_id => p.id}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true, :score => p.score, :post_id => p.id}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {flash[:notice] = "You've already voted for this post"; redirect_to(:action => "show", :id => params[:id])}
        fmt.xml {render :xml => {:success => false, :reason => "already voted"}.to_xml(:root => "response"), :status => 409}
        fmt.js {render :json => {:success => false, :reason => "already voted"}.to_json, :status => 409}
      end
    end
  end

  def delete
    @post = Post.find(params[:id])
  end
  
  def flag
    FlaggedPost.flag(params[:id], params[:reason])
    
    respond_to do |fmt|
      fmt.js {render :json => {:success => true}.to_json}
    end
  end
end
