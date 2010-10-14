class PostController < ApplicationController
  layout 'default'

  verify :method => :post, :only => [:update, :destroy, :create, :revert_tags, :vote, :flag], :redirect_to => {:action => :show, :id => lambda {|c| c.params[:id]}}
  before_filter :member_only, :only => [:create, :upload, :destroy, :flag, :update, :revert_tags, :random]
  before_filter :verify_user_is_not_banned, :only => [:create, :upload, :destroy, :delete, :flag, :update, :revert_tags]
  before_filter :test_janitor_only, :only => [:moderate]
  before_filter :janitor_only, :only => [:undelete, :delete]
  before_filter :privileged_only, :only => [:flag]
  after_filter :save_recent_tags, :only => [:update, :create]  
  # around_filter :cache_action, :only => [:index, :atom, :piclens]

  helper :wiki, :tag, :comment, :pool, :favorite, :advertisement

protected
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

public
  def upload
    if params[:url]
      @post = Post.find(:first, :conditions => ["source = ?", params[:url]])
      @artists = Artist.find_all_by_url(params[:url]).map do |artist|
        [artist.name, 0, CONFIG["tag_types"]["artist"]]
      end
    end
    
    if @post.nil?
      @post = Post.new
    end
  end

  def create
    unless @current_user.can_upload?
      respond_to_error("Daily limit exceeded", {:controller => "user", :action => "upload_limit"}, :status => 421)
      return
    end

    if @current_user.is_contributor_or_higher?
      status = "active"
    else
      status = "pending"
    end

		begin
    	@post = Post.new(params[:post].merge(:updater_user_id => @current_user.id, :updater_ip_addr => request.remote_ip))
    	@post.user_id = @current_user.id
    	@post.status = status
    	@post.ip_addr = request.remote_ip
    	@post.save
		rescue Errno::ENOENT
			respond_to_error("Internal error. Try uploading again.", {:controller => "post", :action => "error"})
			return
		end

    if @post.errors.empty?
      if params[:md5] && @post.md5 != params[:md5].downcase
        @post.destroy
        respond_to_error("MD5 mismatch", {:action => "error"}, :status => 420)
      else
        respond_to_success("Post uploaded", {:controller => "post", :action => "show", :id => @post.id, :tag_title => @post.tag_title}, :api => {:post_id => @post.id, :location => url_for(:controller => "post", :action => "show", :id => @post.id)})
      end
    elsif @post.errors.invalid?(:md5)
      p = Post.find_by_md5(@post.md5)

      update = { :tags => p.cached_tags + " " + params[:post][:tags], :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip }
      update[:source] = @post.source if p.source.blank? && !@post.source.blank?
      p.update_attributes(update)

      respond_to_error("Post already exists", {:controller => "post", :action => "show", :id => p.id, :tag_title => @post.tag_title}, :api => {:location => url_for(:controller => "post", :action => "show", :id => p.id)}, :status => 423)
    else
      respond_to_error(@post, :action => "error")
    end
  end

  def moderate
    if request.post?
      begin
        params[:id].split(/,/).each do |post_id|
          post = Post.find(post_id)
      
          if params[:commit] == "Hide"
            post.mod_hide!(@current_user.id)
          elsif params[:commit] == "Approve"
            post.approve!(@current_user.id)
          elsif params[:commit] == "Delete"
            Post.destroy_with_reason(post.id, params[:reason], @current_user)
          end
        end

        respond_to_success("Post updated", {:action => "moderate"})
      rescue Exception => x
        respond_to_error(x.message, {:action => "error"})
      end
    else
      if @current_user.is_contributor?
        access_denied()
        return
      end

      if params[:query]
        @posts = Post.find_by_sql(Post.generate_sql(params[:query] + " status:pending"))
        @posts += Post.find_by_sql(Post.generate_sql(params[:query] + " status:flagged"))
      else
        @posts = Post.find(:all, :conditions => "status = 'pending'")
        @posts += Post.find(:all, :conditions => "status = 'flagged'")
      end

      @posts = ModQueuePost.reject_hidden(@posts, @current_user, params[:hidden])
      @posts = @posts.sort_by do |post|
        if post.flag_detail
          post.flag_detail.created_at
        else
          post.created_at
        end
      end
    end
  end

  def update
    @post = Post.find(params[:id])
    params[:post][:tags] ||= @post.cached_tags

    if @post.update_attributes(params[:post].merge(:updater_user_id => @current_user.id, :updater_ip_addr => request.remote_ip))
      # Reload the post to send the new status back; not all changes will be reflected in
      # @post due to after_save changes.
      @post.reload
      respond_to_success("Post updated", {:action => "show", :id => @post.id, :tag_title => @post.tag_title}, :api => {:post => @post})
    else
      respond_to_error(@post, :action => "show", :id => params[:id])
    end
  end

  def delete
    @post = Post.find(params[:id])
    
    if @post && @post.parent_id
      @post_parent = Post.find(@post.parent_id)
    end
  end
  
  def destroy
    if params[:commit] == "Cancel"
      redirect_to :action => "show", :id => params[:id]
      return
    end
  
    @post = Post.find(params[:id])

    if @current_user.is_janitor_or_higher?
      begin
        if @post.status == "deleted" && @current_user.is_mod_or_higher?
          @post.delete_from_database
        else
          Post.destroy_with_reason(@post.id, params[:reason], @current_user)
        end
      rescue Post::FlaggingError => x
        respond_to_error(x.message, :action => "error")
        return
      end

      respond_to_success("Post deleted", :action => "show", :id => @post.id)
    else
      access_denied()
    end
  end
  
  def deleted_index
    if params[:user_id]
      @posts = Post.paginate(:per_page => 25, :order => "flagged_post_details.created_at DESC", :joins => "JOIN flagged_post_details ON flagged_post_details.post_id = posts.id", :select => "flagged_post_details.reason, posts.cached_tags, posts.id, posts.user_id", :conditions => ["posts.status = 'deleted' AND posts.user_id = ? ", params[:user_id]], :page => params[:page])
    else
      @posts = Post.paginate(:per_page => 25, :order => "flagged_post_details.created_at DESC", :joins => "JOIN flagged_post_details ON flagged_post_details.post_id = posts.id", :select => "flagged_post_details.reason, posts.cached_tags, posts.id, posts.user_id", :conditions => ["posts.status = 'deleted'"], :page => params[:page])
    end
  end

private
  def index_after_thousand(tags, per_page, before_id)
    @posts = Post.find_by_sql(Post.generate_sql(tags.join(" "), :order => "p.id DESC", :limit => per_page, :before_id => before_id.to_i))
  end
  
  def index_before_thousand(tags, page, per_page)
    post_count = Post.fast_count(tags.join(" "), :user => @current_user)
    @posts = WillPaginate::Collection.create(page, per_page, post_count) do |pager|
      pager.replace(Post.find_by_sql(Post.generate_sql(tags.join(" "), :order => "p.id DESC", :offset => pager.offset, :limit => pager.per_page)))
    end
    
    # @tag_suggestions = Tag.find_suggestions(tags.join(" ")) if post_count < 20 && tags.size == 1
  end

public
  def index
    tags = params[:tags].to_s
    @tags = QueryParser.parse(tags)
    page = params[:page].to_i; page = 1 if page == 0
    limit = params[:limit].to_i; limit = 20 if limit == 0; limit = 1000 if limit > 1000
    before_id = params[:before_id]
    
    if page > 1000
      respond_to_error("You can only search up to page 1,000", :action => "error")
      return
    end
    
    if @current_user.is_member_or_lower? && @tags.size > 2
      respond_to_error("You can only search up to two tags at once with a basic account", :action => "error")
      return
    elsif @tags.size > 6
      respond_to_error("You can only search up to six tags at once", :action => "error")
      return
    elsif @tags.size == 1 && @tags.first !~ /(user|fav|sub):/
      @artist = Artist.find_by_name(@tags.first)
      @wiki_page = WikiPage.find_page(@tags.first)
    end
    
    begin
      db_start_time = Time.now
      set_title "/" + tags.tr("_", " ")
      @db_delta_time = Time.now - db_start_time

      if before_id
        index_after_thousand(@tags, limit, before_id)
      else
        index_before_thousand(@tags, page, limit)

        # If there are blank pages for this query, then fix the post count
        if @posts.size == 0 && page > 1 && @tags.size == 1 && JobTask.pending_count("calculate_post_count") < 1000
          JobTask.create(:task_type => "calculate_post_count", :data => {"tag_name" => @tags[0]}, :status => "pending")
        end
      end
    
      respond_to do |fmt|
        fmt.html do
          # @ambiguous_tags = Tag.select_ambiguous(@tags)
          @render_start_time = Time.now
        end
        fmt.xml do
          render :layout => false
        end
        fmt.json do
          render :json => @posts.to_json
        end
      end
    rescue RuntimeError => e
      respond_to_error(e.to_s, :action => "error")
    end
  end

  def atom
    begin
      @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :user => @current_user, :limit => 20, :order => "p.id DESC"))
      headers["Content-Type"] = "application/atom+xml"
    rescue RuntimeError => e
      @posts = []
    end
    
    render :layout => false
  end

  def piclens
    @posts = WillPaginate::Collection.create(params[:page], 20, Post.fast_count(params[:tags])) do |pager|
      pager.replace(Post.find_by_sql(Post.generate_sql(params[:tags], :user => @current_user, :order => "p.id DESC", :offset => pager.offset, :limit => pager.per_page)))
    end
    
    headers["Content-Type"] = "application/rss+xml"
    render :layout => false
  end

  def show
    begin
      if params[:md5]
        @post = Post.find_by_md5(params[:md5].downcase) || raise(ActiveRecord::RecordNotFound)
      else
        @post = Post.find(params[:id])
      end
      
      @pools = Pool.find(:all, :joins => "JOIN pools_posts ON pools_posts.pool_id = pools.id", :conditions => "pools_posts.post_id = #{@post.id}", :order => "pools.name", :select => "pools.name, pools.id")
      @tags = {:include => @post.cached_tags.split(/ /)}
      set_title @post.cached_tags.tr("_", " ")
    rescue ActiveRecord::RecordNotFound
      render :action => "show_empty", :status => 404
    end
  end

  def popular_by_day
		begin
	    if params[:year] && params[:month] && params[:day]
	      @day = Time.gm(params[:year].to_i, params[:month], params[:day])
	    else
	      @day = Time.new.getgm.at_beginning_of_day
	    end
		rescue ArgumentError
			respond_to_error("Date out of range", :controller => "post", :action => "error")
			return
		end
		
    set_title "Exploring #{@day.year}/#{@day.month}/#{@day.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at <= ? ", @day, @day.tomorrow], :order => "score DESC", :limit => 20)

    respond_to_list("posts")
  end

  def popular_by_week
		begin
	    if params[:year] && params[:month] && params[:day]
	      @start = Time.gm(params[:year].to_i, params[:month], params[:day]).beginning_of_week
	    else
	      @start = Time.new.getgm.beginning_of_week
	    end
		rescue ArgumentError
			respond_to_error("Date out of range", :controller => "post", :action => "error")
			return
		end

    @end = @start.next_week

    set_title "Exploring #{@start.year}/#{@start.month}/#{@start.day} - #{@end.year}/#{@end.month}/#{@end.day}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20)

    respond_to_list("posts")
  end

  def popular_by_month
		begin
	    if params[:year] && params[:month]
	      @start = Time.gm(params[:year].to_i, params[:month], 1)
	    else
	      @start = Time.new.getgm.beginning_of_month
	    end
		rescue ArgumentError
			respond_to_error("Date out of range", :controller => "post", :action => "error")
			return
		end

    @end = @start.next_month

    set_title "Exploring #{@start.year}/#{@start.month}"

    @posts = Post.find(:all, :conditions => ["posts.created_at >= ? AND posts.created_at < ? ", @start, @end], :order => "score DESC", :limit => 20)

    respond_to_list("posts")
  end

  def revert_tags
    user_id = @current_user.id
    @post = Post.find(params[:id])
    @post.update_attributes(:tags => PostTagHistory.find(params[:history_id].to_i).tags, :updater_user_id => user_id, :updater_ip_addr => request.remote_ip)

    respond_to_success("Tags reverted", :action => "show", :id => @post.id, :tag_title => @post.tag_title)
  end

  def vote
    p = Post.find(params[:id])
    score = params[:score].to_i
    respond_to_params = {:action => "show", :id => params[:id], :tag_title => p.tag_title}
  
    begin
      p.vote!(@current_user, score)
      respond_to_success("Vote saved", respond_to_params, :api => {:score => p.score, :post_id => p.id})
    rescue Post::VotingError => x
      respond_to_error(x.message, respond_to_params, :status => 424)
    end
  end

  def flag
    begin
      post = Post.find(params[:id])
      raise Post::FlaggingError.new("Post was previously unapproved") if post.flag_detail
      post.flag!(params[:reason], @current_user)
      respond_to_success("Post flagged", :action => "show", :id => params[:id])
    rescue Post::FlaggingError => x
      respond_to_error(x.message, :action => "show", :id => params[:id])
    end
  end
  
  def random
    max_id = Post.maximum(:id)
    
    10.times do
      post = Post.find(:first, :conditions => ["id = ? AND status <> 'deleted'", rand(max_id) + 1], :select => "id, cached_tags, status")

      if post != nil && post.can_be_seen_by?(@current_user)
        redirect_to :action => "show", :id => post.id, :tag_title => post.tag_title
        return
      end
    end
    
    flash[:notice] = "Couldn't find a post in 10 tries. Try again."
    redirect_to :action => "index"
  end
  
  def undelete
    @post = Post.find(params[:id])
    
    if request.post?
      if params[:commit] == "Undelete"
        @post.undelete!(@current_user)
        respond_to_success("Post was undeleted", :action => "show", :id => @post.id)
      else
        redirect_to(:action => "show", :id => @post.id)
      end
    end
  end
  
  def error
  end
  
  def recent_approvals
    user_level = params[:level] || 34
    @posts = Post.paginate(:conditions => ["posts.approver_id is not null and posts.created_at > ? and users.level = ? and status <> 'deleted'", 1.month.ago, user_level.to_i], :order => "id desc", :per_page => 20, :page => params[:page], :select => "posts.*", :joins => "join users on users.id = posts.approver_id")
  end
  
  def exception
    raise "error"
  end
  
private
  def save_recent_tags
    if params[:tags] || (params[:post] && params[:post][:tags])
      tags = Tag.scan_tags(params[:tags] || params[:post][:tags])
      tags = TagAlias.to_aliased(tags) + Tag.scan_tags(@current_user.recent_tags)
      @current_user.update_attribute(:recent_tags, tags.uniq.slice(0, 25).join(" "))
    end
  end
end
