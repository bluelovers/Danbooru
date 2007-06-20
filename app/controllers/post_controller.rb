class PostController < ApplicationController
  layout 'default'
  
  verify :method => :post, :only => [:update, :destroy, :create, :revert_tags, :vote]

  if CONFIG["enable_anonymous_post_access"]
    if CONFIG["enable_anonymous_post_uploads"]
      before_filter :user_only, :only => [:destroy]
    else
      before_filter :user_only, :only => [:destroy, :create, :upload]
    end
  else
    before_filter :user_only
  end
  
  if CONFIG["enable_caching"]
    around_filter :cache_action, :only => [:index, :atom]
  end

  after_filter :save_tags_to_cookie, :only => [:update, :create]
  helper :wiki, :tag, :comment
  
# Parameters
# - post[source]: alternative to post[file], source url to download from
# - post[file]: alternative to post[source], should contain multipart form data
# - post[tags]: a space delimited string of tags
# - post[is_rating_locked]: OPTIONAL, lock rating changes
# - post[is_note_locked]: OPTIONAL, lock note changes
# - post[next_post_id]: OPTIONAL
# - post[prev_post_id]: OPTIONAL
# - login: OPTIONAL, login name
# - password: alternative to password_hash, your plaintext password
# - password_hash: alternative to password, your salted, hashed password (stored in a cookie called pass_hash)
# - md5: OPTIONAL, used to verify the upload's integrity
  def create
    user_id = @current_user.id rescue nil

    @post = Post.create(params["post"].merge(:updater_user_id => user_id, :updater_ip_addr => request.remote_ip, :user_id => user_id, :ip_addr => request.remote_ip))

    if @post.errors.empty?
      if params[:md5] && @post.md5 != params[:md5].downcase
        @post.destroy
        respond_to do |fmt|
          fmt.html {flash[:notice] = "MD5 mismatch"; redirect_to(:controller => "post", :action => "index")}
          fmt.xml {render :xml => {:success => false, :reason => "md5 mismatch"}.to_xml}
          fmt.js {render :json => {:success => false, :reason => "md5 mismatch"}.to_json}
        end
      else
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Post successfully uploaded"; redirect_to(:controller => "post", :action => "show", :id => @post.id)}
          fmt.xml {render :xml => {:success => true, :location => url_for(:controller => "post", :action => "show", :id => @post.id)}.to_xml}
          fmt.js {render :json => {:success => true, :location => url_for(:controller => "post", :action => "show", :id => @post.id)}.to_json}
        end
      end
    elsif @post.errors.invalid?(:md5)
      p = Post.find_by_md5(@post.md5)
      p.update_attributes(:tags => p.cached_tags + " " + params[:post][:tags], :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip, :rating => params[:post][:rating])

      respond_to do |fmt|
        fmt.html {flash[:notice] = "That post already exists"; redirect_to(:controller => "post", :action => "show", :id => p.id)}
        fmt.xml {render :xml => {:success => false, :reason => "duplicate", :location => url_for(:controller => "post", :action => "show", :id => p.id)}.to_xml}
        fmt.js {render :json => {:success => false, :reason => "duplicate", :location => url_for(:controller => "post", :action => "show", :id => p.id)}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {render_error(@post)}
        fmt.xml {render :xml => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_xml, :status => 500}
        fmt.js {render :json => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_json, :status => 500}
      end
    end
  end

  def upload #:nodoc:
    @post = Post.new
  end

# Parameters
# - post[source]: alternative to post[file], source url to download from
# - post[file]: alternative to post[source], should contain multipart form data
# - post[tags]: a space delimited string of tags
# - post[is_rating_locked]: OPTIONAL, lock rating changes
# - post[is_note_locked]: OPTIONAL, lock note changes
# - post[next_post_id]: OPTIONAL
# - post[prev_post_id]: OPTIONAL
# - id: the ID number of the post to update
# - login: OPTIONAL, login name
# - password: alternative to password_hash, your plaintext password
# - password_hash: alternative to password, your salted, hashed password (stored in a cookie called pass_hash)
  def update
    @post = Post.find(params["id"])
    user_id = current_user().id rescue nil

    if @post.update_attributes(params["post"].merge(:updater_user_id => user_id, :updater_ip_addr => request.remote_ip))
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post updated"; redirect_to(:action => "show", :id => @post.id)}
        fmt.xml {render :xml => {:success => true}.to_xml}
        fmt.js {render :json > {:success => true}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {render_error(@post)}
        fmt.xml {render :xml => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_xml, :status => 500}
        fmt.js {render :json => {:success => false, :reason => @post.errors.full_messages.join(" ")}.to_json, :status => 500}
      end
    end
  end

# Parameters
# - id: the ID number of the post to destroy
# - login: login name
# - password: alternative to password_hash, your plaintext password
# - password_hash: alternative to password, your salted, hashed password (stored in a cookie called pass_hash)
  def destroy
    @post = Post.find(params["id"])
    if @current_user.has_permission?(@post)
      @post.destroy

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post successfully deleted"; redirect_to(:action => "index")}
        fmt.xml {render :xml => {:success => true}.to_xml}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      access_denied()
    end
  end

# Parameters
# - limit: maximum number of posts to show on one response
# - page: page number (starts at 1)
# - tags: a space delimited string representing the tags to search for
  def index
    set_title "/#{params[:tags]}"

    if @current_user == nil && CONFIG["enable_multi-tag_search_for_anonymous"] == false && params[:tags].to_s.include?(" ")
      flash[:notice] = "You must be logged in to search for more than one tag at a time."
      redirect_to :controller => "user", :action => "login"
      return
    end

    limit = params[:limit].to_i
    if limit == 0 || limit > 100
      limit = 15
    end

    tag_blacklist = (@current_user ? @current_user.tag_blacklist.scan(/\S+/) : [])
    user_blacklist = (@current_user ? @current_user.user_blacklist.scan(/\S+/) : [])
    post_threshold = (@curent_user ? @current_user.post_threshold : nil)

    @ambiguous = Tag.select_ambiguous(params[:tags])
    @pages = Paginator.new(self, Post.fast_count(params[:tags]), limit, params[:page])
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC", :offset => @pages.current.offset, :limit => @pages.items_per_page, :tag_blacklist => tag_blacklist, :user_blacklist => user_blacklist, :post_threshold => post_threshold))

    if @posts.empty? && !params[:tags].blank? && CONFIG["enable_suggestions_on_no_results"]
      @suggestions = Tag.find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\'", "%" + params[:tags].to_escaped_for_sql_like + "%"], :order => "name").map {|x| x.name}
    else
      @suggestions = []
    end

    respond_to do |fmt|
      fmt.html {@tags = (params[:tags] ? Tag.parse_query(params[:tags]) : {:include => Tag.find(:all, :order => "post_count DESC", :limit => 25)})}
      fmt.xml {render :xml => @posts.to_xml}
      fmt.js {render :json => @posts.to_json}
    end
  end

  def atom #:nodoc:
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :limit => 24, :order => "p.id DESC"))
    render :layout => false
  end

  def moderate
    @post = Post.find(params[:id])

    if request.post?
      @post.update_attributes(params[:post])
      redirect_to :controller => "post", :action => "show", :id => @post.id
    end
  end

  def show #:nodoc:
    begin
      @post = Post.find(params[:id])
      if !@current_user && CONFIG["enable_anonymous_safe_post_mode"] && @post.rating != 's'
        flash[:notice] = "You must be logged in to view this post"
        redirect_to :controller => "user", :action => "login"
        return
      end
      @tags = {:include => @post.cached_tags.split(/ /)}
      set_title @post.cached_tags
    rescue ActiveRecord::RecordNotFound
      flash.now[:notice] = "That post ID was not found"
      @post = nil
    end
  end

# Parameters
# - year: self-explanatory
# - month: self-explanatory
# - day: self-explanatory
# - select: for API calls, a comma delimited list of specific fields to pull. can be: created_at, author, score, md5, preview, file, rating, tags, next, previous
  def popular_by_day
    if params["year"] and params["month"] and params["day"]
      @day = Time.gm(params["year"].to_i, params["month"], params["day"])
    else
      @day = Time.new.getgm.at_beginning_of_day
    end

    set_title "Exploring #{@day.year}/#{@day.month}/#{@day.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at <= ?", @day, @day.tomorrow], :order => "score DESC", :limit => 20, :include => [:user])
    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.to_xml(:select => params[:select].to_s.split(/,/))}
      fmt.js {render :json => @posts.to_json(:select => params[:select].to_s.split(/,/))}
    end
  end

# Parameters
# - year: self-explanatory
# - month: self-explanatory
# - day: self-explanatory
# - select: for API calls, a comma delimited list of specific fields to pull. can be: created_at, author, score, md5, preview, file, rating, tags, next, previous
  def popular_by_week
    if params["year"] and params["month"] and params["day"]
      @start = Time.gm(params["year"].to_i, params["month"], params["day"]).beginning_of_week
    else
      @start = Time.new.getgm.beginning_of_week
    end

    @end = @start.next_week

    set_title "Exploring #{@start.year}/#{@start.month}/#{@start.day} - #{@end.year}/#{@end.month}/#{@end.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.to_xml(:select => params[:select].to_s.split(/,/))}
      fmt.js {render :json => @posts.to_json(:select => params[:select].to_s.split(/,/))}
    end
  end

# Parameters
# - year: self-explanatory
# - month: self-explanatory
# - select: for API calls, a comma delimited list of specific fields to pull. can be: created_at, author, score, md5, preview, file, rating, tags, next, previous
  def popular_by_month
    if params["year"] and params["month"]
      @start = Time.gm(params["year"].to_i, params["month"], 1)
    else
      @start = Time.new.getgm.beginning_of_month
    end

    @end = @start.next_month

    set_title "Exploring #{@start.year}/#{@start.month}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ?", @start, @end], :order => "score DESC", :limit => 20, :include => [:user])

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.to_xml(:select => params[:select].to_s.split(/,/))}
      fmt.js {render :json => @posts.to_json(:select => params[:select].to_s.split(/,/))}
    end
  end

# Parameters
# - id: post ID to change
# - history_id: the ID of the post tag history record
# - login: login name
# - password: alternative to password_hash, your plaintext password
# - password_hash: alternative to password, your salted, hashed password (stored in a cookie called pass_hash)
  def revert_tags
    user_id = @current_user.id rescue nil
    @post = Post.find(params[:id])
    @post.update_attributes(:tags => @post.tag_history.find(params[:history_id]).tags, :updater_user_id => user_id, :updater_ip_addr => request.remote_ip)

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Tags reverted"; redirect_to(:action => "show", :id => @post.id)}
      fmt.xml {render :xml => {:success => true}.to_xml}
      fmt.js {render :json => {:success => true}.to_json}
    end
  end

# Parameters
# - limit: OPTIONAL
# - offset: OPTIONAL
# - post_id: OPTIONAL, ID of the post to query
  def tag_changes
    set_title "Tag changes"

    if params[:post_id]
      conditions = ["post_id = ?", params[:post_id]]
    else
      conditions = nil
    end

    limit = params[:limit] || 100

    respond_to do |fmt|
      fmt.html {@pages, @changes = paginate :post_tag_histories, :order => "id DESC", :per_page => 5, :conditions => conditions}
      fmt.xml {render :xml => PostTagHistory.find(:all, :limit => limit, :offset => params[:offset], :order => "id DESC", :conditions => conditions).to_xml}
      fmt.js {render :json => PostTagHistory.find(:all, :limit => limit, :offset => params[:offset], :order => "id DESC", :conditions => conditions).to_json}
    end
  end

# Parameters
# - id: post ID number
  def favorites
    set_title "Users who favorited this post"
    @post = Post.find(params["id"])
    @users = User.find_people_who_favorited(params["id"])

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @users.to_xml}
      fmt.js {render :json => @users.to_json}
    end
  end

# Parameters
# - id: post ID number
# - score: the score (must be either 1 or -1)
  def vote
    p = Post.find(params[:id])
    score = params[:score].to_i

    unless score == 1 || score == -1
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Invalid score"; redirect_to(:action => "show", :id => params[:id])}
        fmt.xml {render :xml => {:success => false, :reason => "invalid score"}.to_xml, :status => 409}
        fmt.js {render :json => {:success => false, :reason => "invalid score"}.to_json, :status => 409}
      end
      return
    end

    if p.vote!(score, request.remote_ip)
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Vote saved"; redirect_to(:action => "show", :id => params[:id])}
        fmt.xml {render :xml => {:success => true}.to_xml}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      respond_to do |fmt|
        fmt.html {flash[:notice] = "You've already voted for this post"; redirect_to(:action => "show", :id => params[:id])}
        fmt.xml {render :xml => {:success => false, :reason => "already voted"}.to_xml, :status => 409}
        fmt.js {render :json => {:success => false, :reason => "already voted"}.to_json, :status => 409}
      end
    end
  end
end
