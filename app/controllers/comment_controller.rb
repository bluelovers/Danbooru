class CommentController < ApplicationController
  layout "default"

  verify :method => :post, :only => [:create, :destroy, :update], :render => {:nothing => true}

  if CONFIG["enable_comment_spam_filter"]
    before_filter :spam_filter, :only => :create
  end

  if CONFIG["enable_anonymous_comment_access"]
    if CONFIG["enable_anonymous_comment_responses"]
      before_filter :user_only, :only => [:destroy, :update]
    else
      before_filter :user_only, :only => [:create, :destroy, :update]
    end
  else
    before_filter :user_only
  end

  before_filter :mod_only, :only => [:moderate]

  def spam_filter
    return false if params[:comment][:body].scan(/http/).size > 2
    return true
  end

  def update
    comment = Comment.find(params[:id])
    if @current_user.has_permission?(comment)
      comment.update_attributes(params[:comment])
      respond_to do |fmt|
        fmt.xml {render :xml => {:success => true}.to_xml("response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      access_denied()
    end
  end

  def destroy
    comment = Comment.find(params[:id])
    if @current_user.has_permission?(comment)
      comment.destroy

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Comment deleted"; redirect_to(:controller => "post", :action => "show", :id => comment.post_id)}
        fmt.xml {render :xml => {:success => true}.to_xml("response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      access_denied()
    end
  end

  def create
    if params[:comment][:anonymous] == "1"
      user_id = nil
      params[:comment].delete(:anonymous)
    else
      user_id = session[:user_id]
    end

    comment = Comment.create(params[:comment].merge(:ip_addr => request.remote_ip, :user_id => user_id))
    if comment.errors.empty?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Comment added"; redirect_to(:action => "index")}
        fmt.xml {render :xml => {:success => true}.to_xml("response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      error_messages = comment.errors.full_messages.join(", ")
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Error: #{h(error_messages)}"; redirect_to(:action => "show", :id => comment.post_id)}
        fmt.xml {render :xml => {:success => false, :reason => error_messages}.to_xml("response")}
        fmt.js {render :json => {:success => false, :reason => error_messages}.to_json}
      end
    end
  end

  def show
    set_title "Comment"
    @comment = Comment.find(params[:id])

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @comment.to_xml}
      fmt.js {render :json => @comment.to_json}
    end
  end

  def index
    set_title "Comments"

		params[:limit] ||= 25
    cond = ["TRUE"]
    cond_params = []

    if params[:post_id]
      cond << "post_id = ?"
      cond_params << params[:post_id].to_i
    end

    respond_to do |fmt|
      fmt.html do
        @pages, @posts = paginate :posts, :order => "last_commented_at DESC", :conditions => "last_commented_at IS NOT NULL", :per_page => 10
      end
      fmt.xml {render :xml => Comment.find(:all, :conditions => [cond.join(" AND "), *cond_params], :limit => params[:limit], :order => "id DESC", :offset => params[:offset]).to_xml}
      fmt.js {render :json => Comment.find(:all, :conditions => [cond.join(" AND "), *cond_params], :limit => params[:limit], :order => "id DESC", :offset => params[:offset]).to_json}
    end
  end

  def moderate
    set_title "Moderate Comments"

    if request.post?
      ids = params["c"].keys
      coms = Comment.find(:all, :conditions => ["id IN (?)", ids])

      if params["commit"] == "Delete"
        coms.each do |c|
          c.destroy
        end
      elsif params["commit"] == "Accept"
        coms.each do |c|
          c.update_attribute(:is_spam, false)
        end
      end

      redirect_to :action => "moderate"
    else
      @comments = Comment.find(:all, :conditions => "is_spam = TRUE", :order => "id DESC")
    end
  end

	def mark_as_spam
		@comment = Comment.find(params[:id])
		@comment.update_attributes(:is_spam => true)
		respond_to do |fmt|
			fmt.xml {render :xml => {:success => true}.to_xml("response")}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end
end if CONFIG["enable_comments"]
