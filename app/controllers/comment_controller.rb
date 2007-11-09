class CommentController < ApplicationController
  layout "default"

  verify :method => :post, :only => [:create, :destroy, :update, :mark_as_spam]
  before_filter :member_only, :only => [:create, :destroy, :update]
  before_filter :mod_only, :only => [:moderate]

  def update
    comment = Comment.find(params[:id])
    if @current_user.has_permission?(comment)
      comment.update_attributes(params[:comment])
      respond_to do |fmt|
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
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
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      access_denied()
    end
  end

  def create
    if @current_user.level == User::LEVEL_MEMBER && Comment.count(:conditions => ["user_id = ? AND created_at > ?", @current_user.id, 1.hour.ago]) >= CONFIG["member_comment_limit"]
      respond_to do |fmt|
        fmt.html {flash[:notice] = "You cannot post more than #{CONFIG['member_comment_limit']} comments in an hour"; redirect_to(:controller => "comment", :action => "index")}
        fmt.xml {render :xml => {:success => false, :reason => "hourly limit exceeded"}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :json => {:success => false, :reason => "hourly limit exceeded"}.to_json, :status => 500}
      end

      return
    end

    if params[:commit] == "Post as Anonymous"
      user_id = nil
    else
      user_id = session[:user_id]
    end

    comment = Comment.create(params[:comment].merge(:ip_addr => request.remote_ip, :user_id => user_id))
    if comment.errors.empty?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Comment added"; redirect_to(:controller => "comment", :action => "index")}
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      error_messages = comment.errors.full_messages.join(", ")
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Error: #{error_messages}"; redirect_to(:controller => "post", :action => "show", :id => comment.post_id)}
        fmt.xml {render :xml => {:success => false, :reason => error_messages}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => false, :reason => error_messages}.to_json}
      end
    end
  end

  def show
    set_title "Comment"
    @comment = Comment.find(params[:id])

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @comment.to_xml(:root => "comments")}
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
        if hide_explicit?
          @pages, @posts = paginate :posts, :order => "last_commented_at DESC", :conditions => "last_commented_at IS NOT NULL AND rating <> 'e' AND status = 'active'", :per_page => 10
        else
          @pages, @posts = paginate :posts, :order => "last_commented_at DESC", :conditions => "last_commented_at IS NOT NULL AND status > 'deleted'", :per_page => 10
        end
      end
      fmt.xml {render :xml => Comment.find(:all, :conditions => [cond.join(" AND "), *cond_params], :limit => params[:limit], :order => "id DESC", :offset => params[:offset]).to_xml(:root => "comments")}
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
      elsif params["commit"] == "Approve"
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
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
      fmt.js {render :json => {:success => true}.to_json}
    end
  end
end
