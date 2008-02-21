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
    if @current_user.level == User::LEVEL_MEMBER && Post.count(:conditions => ["user_id = ? AND created_at > ? ", @current_user.id, 1.day.ago]) >= CONFIG["member_post_limit"]
      respond_to do |fmt|
        fmt.html {flash[:notice] = "You cannot upload more than #{CONFIG['member_post_limit']} posts in a day"; redirect_to(:action => "upload")}
        fmt.xml {render :xml => {:success => false, :reason => "daily limit exceeded"}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :json => {:success => false, :reason => "daily limit exceeded"}.to_json, :status => 500}
      end

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
        respond_to do |fmt|
          fmt.html {flash[:notice] = "MD5 mismatch"; redirect_to(:controller => "post", :action => "index", :tag_title => @post.tag_title)}
          fmt.xml {render :xml => {:success => false, :reason => "md5 mismatch"}.to_xml(:root => "response")}
          fmt.js {render :json => {:success => false, :reason => "md5 mismatch"}.to_json}
        end
      else
        respond_to do |fmt|
          fmt.html do
            flash[:notice] = "Post successfully uploaded"
            redirect_to(:controller => "post", :action => "show", :id => @post.id, :tag_title => @post.tag_title)
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
          redirect_to(:controller => "post", :action => "show", :id => p.id, :tag_title => @post.tag_title)
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
        if params[:ids]
          params[:ids].keys.each do |post_id|
            if params[:commit] == "Approve"
              Post.update(post_id, :status => "active")
            elsif params[:commit] == "Delete"
              Post.update(post_id, :deletion_reason => (params[:reason] || params[:reason2])) unless params[:reason].blank? && params[:reason2].blank?
              Post.destroy(post_id)
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
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post updated"; redirect_to(:action => "show", :id => @post.id, :tag_title => @post.tag_title)}
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

    if @current_user.has_permission?(@post)
      unless params[:reason].blank?
        @post.update_attribute(:deletion_reason, params[:reason])
      end

      if @post.status == "deleted" || @post.user_id == @current_user.id
        @post.delete_from_database
      else
        @post.destroy
      end

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post deleted"; redirect_to(:action => "index")}
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Access denied"; redirect_to(:action => "show", :id => @post.id)}
        fmt.xml {render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 403}
        fmt.js {render :json => {:success => false, :reason => "access denied"}.to_json, :status => 403}
      end
    end
  end
  
  def deleted_index
    if params[:user_id]
      @pages, @posts = paginate :posts, :order => "id desc", :per_page => 25, :select => "deletion_reason, cached_tags, id, user_id", :conditions => ["status = 'deleted' and user_id = ? ", params[:user_id]]
    else
      @pages, @posts = paginate :posts, :order => "id desc", :per_page => 25, :select => "deletion_reason, cached_tags, id, user_id", :conditions => ["status = 'deleted'"]
    end
  end

  def index
    tags = params[:tags].to_s
    split_tags = tags.scan(/\S+/)
    page = params[:page].to_i
    page = 1 if page < 1
    limit = params[:limit].to_i
    limit = 16 if limit == 0
    limit = 1000 if limit > 1000

    set_title "/" + tags.tr("_", " ")

    if @current_user.is_anonymous?
      if CONFIG["show_only_first_page"] && page > 1
        flash[:notice] = "You need an account to look beyond the first page."
        redirect_to :controller => "user", :action => "login"
        return
      end

      if split_tags.size > 1
        flash[:notice] = "You need an account to search for more than one tag at once."
        redirect_to :controller => "user", :action => "login"
        return
      end

    elsif !@current_user.is_privileged_or_higher?
      if split_tags.size > 2
        flash[:notice] = "You need a privileged account to search for more than two tags at once."
        redirect_to :controller => "user", :action => "login"
        return
      end
    end

    @ambiguous = Tag.select_ambiguous(tags)
    
    if !@current_user.is_privileged_or_higher?
      count = Post.fast_count(tags, false)
    else
      count = Post.fast_count(tags)
    end

    if count > 0
      @pages = Paginator.new(self, count, limit, page)
      if !@pages.has_page_number?(page)
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Invalid page"; redirect_to(:action => "index", :id => params[:tags])}
          fmt.xml {render :xml => {:success => false, :reason => "invalid page"}.to_xml(:root => "response"), :status => 404}
          fmt.js {render :json => {:success => false, :reason => "invalid page"}.to_json, :status => 404}
        end
        return
      end
      @posts = Post.find_by_sql(Post.generate_sql(tags, :order => "p.id DESC", :offset => @pages.current.offset, :limit => @pages.items_per_page))
    else
      @posts = Post.find_by_sql(Post.generate_sql(tags, :order => "p.id DESC", :offset => (limit * (page -1)), :limit => limit))
    end

    if @posts.empty? && split_tags.any? && page == 1
      @suggestions = Tag.find(:all, :select => "name", :conditions => ["name LIKE ? ESCAPE '\\\\'", "%" + tags.to_escaped_for_sql_like + "%"], :order => "name", :limit => 10).map {|x| x.name}
    else
      @suggestions = []
    end

    respond_to do |fmt|
      fmt.html do        
        if split_tags.any?
          @tags = Tag.parse_query(tags)
        else
          if CONFIG["enable_caching"]
            @tags = Cache.get("$poptags", 1.day) do
              {:include => Tag.count_by_period(3.days.ago, Time.now, :limit => 25)}
            end
          else
            @tags = {:include => Tag.count_by_period(3.days.ago, Time.now, :limit => 25)}
          end
        end
      end
      fmt.xml do
        x = Builder::XmlMarkup.new(:indent => 2)
        x.instruct!
        render :xml => x.posts(:count => count, :offset => (limit * (page - 1))) {
          @posts.each { |e|
            e.to_xml(:builder => x, :skip_instruct => true)
          }
        }
      end
      fmt.js {render :json => @posts.to_json}
    end
  end

  def atom
    if !@current_user.is_privileged_or_higher? && params[:tags].to_s.scan(/\s+/).size > 2
      render :nothing => true, :status => 500
      return
    end
    
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :limit => 24, :order => "p.id DESC"))
    @headers["Content-Type"] = "application/atom+xml"
    render :layout => false
  end

  def piclens
    if !@current_user.is_privileged_or_higher? && params[:tags].to_s.scan(/\s+/).size > 2
      render :nothing => true, :status => 500
      return
    end
 
    @tags = params[:tags].to_s
    page = params[:page].to_i
    limit = 16
    page = 1 if page < 1

    if !@current_user.is_privileged_or_higher?
      count = Post.fast_count(@tags, false)
    else
      count = Post.fast_count(@tags)
    end

    if count > 0
      @pages = Paginator.new(self, count, limit, page)
      if !@pages.has_page_number?(page)
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Invalid page"; redirect_to(:action => "index", :id => params[:tags])}
          fmt.xml {render :xml => {:success => false, :reason => "invalid page"}.to_xml(:root => "response"), :status => 404}
          fmt.js {render :json => {:success => false, :reason => "invalid page"}.to_json, :status => 404}
        end
        return
      end
      @posts = Post.find_by_sql(Post.generate_sql(@tags, :order => "p.id DESC", :offset => @pages.current.offset, :limit => @pages.items_per_page))
    else
      @posts = Post.find_by_sql(Post.generate_sql(@tags, :order => "p.id DESC", :offset => (limit * (page -1)), :limit => limit))
    end
    
    @headers["Content-Type"] = "application/rss+xml"
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

    if @current_user.is_privileged_or_higher?
      @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at <= ? ", @day, @day.tomorrow], :order => "score DESC", :limit => 20, :include => [:user])
    else
      @posts = Post.find(:all, :conditions => ["posts.rating = 's' AND posts.status = 'active' AND posts.created_at >= ? AND posts.created_at <= ? ", @day, @day.tomorrow], :order => "score DESC", :limit => 20, :include => [:user])
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

    if @current_user.is_privileged_or_higher?
      @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
    else
      @posts = Post.find(:all, :conditions => ["posts.rating = 's' AND posts.status = 'active' AND posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
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

    if @current_user.is_privileged_or_higher?
      @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
    else
      @posts = Post.find(:all, :conditions => ["posts.rating = 's' AND posts.status = 'active' AND posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])
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
      fmt.html {flash[:notice] = "Tags reverted"; redirect_to(:action => "show", :id => @post.id, :tag_title => @post.tag_title)}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
      fmt.js {render :json => {:success => true}.to_json}
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
    
    if !@current_user.is_mod_or_higher? && score != 1 && score != -1
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Invalid score"; redirect_to(:action => "show", :id => params[:id], :tag_title => p.tag_title)}
        fmt.xml {render :xml => {:success => false, :reason => "invalid score"}.to_xml(:root => "response"), :status => 409}
        fmt.js {render :json => {:success => false, :reason => "invalid score"}.to_json, :status => 409}
      end
      return
    end

    if p.vote!(score, request.remote_ip)
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Vote saved"; redirect_to(:action => "show", :id => params[:id], :tag_title => p.tag_title)}
        fmt.xml {render :xml => {:success => true, :score => p.score, :post_id => p.id}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true, :score => p.score, :post_id => p.id}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {flash[:notice] = "You've already voted for this post"; redirect_to(:action => "show", :id => params[:id], :tag_title => p.tag_title)}
        fmt.xml {render :xml => {:success => false, :reason => "already voted"}.to_xml(:root => "response"), :status => 409}
        fmt.js {render :json => {:success => false, :reason => "already voted"}.to_json, :status => 409}
      end
    end
  end

  def delete
    @post = Post.find(params[:id])
  end
  
  def flag
    @post = Post.find(params[:id])
    @post.status = 'flagged'
    @post.deletion_reason = params[:reason]
    @post.save
    
    respond_to do |fmt|
      fmt.js {render :json => {:success => true}.to_json}
    end
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
