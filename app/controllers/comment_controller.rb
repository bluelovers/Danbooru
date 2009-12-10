class CommentController < ApplicationController
  layout "default"

  verify :method => :post, :only => [:create, :destroy, :update, :mark_as_spam]
  before_filter :member_only, :only => [:create, :destroy, :update, :show, :vote]
  before_filter :contributor_only, :only => [:moderate]

  def edit
    @comment = Comment.find(params[:id])
  end
  
  def preview
    render :inline => "<h5>Preview</h5><%= format_text(params[:body]) %>"
  end
  
  def update
    comment = Comment.find(params[:id])
    if @current_user.has_permission?(comment)
      comment.update_attributes(params[:comment])
      respond_to_success("Comment updated", {:action => "index"})
    else
      access_denied()
    end
  end

  def destroy
    comment = Comment.find(params[:id])
    if @current_user.has_permission?(comment)
      comment.destroy
      respond_to_success("Comment deleted", :controller => "post", :action => "show", :id => comment.post_id)
    else
      access_denied()
    end
  end

  def create
    comment = Comment.new(params[:comment])
    comment.post_id = params[:comment][:post_id]
    comment.user_id = @current_user.id
    comment.score = 0
    comment.ip_addr = request.remote_ip

    if params[:commit] == "Post without bumping"
      comment.do_not_bump_post = true
    elsif !@current_user.can_comment?
      respond_to_error("Hourly limit exceeded", {:controller => "post", :action => "show", :id => params[:comment][:post_id]}, :status => 421)
      return
    end
    
    if comment.save
      respond_to_success("Comment created", :action => "index")
    else
      respond_to_error(comment, :action => "index")
    end
  end

  def show
    set_title "Comment"
    @comment = Comment.find(params[:id])

    respond_to_list("comment")
  end
  
  def index_hidden
    @comments = Comment.find(:all, :order => "id", :conditions => ["post_id = ?", params[:post_id]])
  end
  
  def index_all
    @show_all = true
    @comments = Comment.find(:all, :order => "id", :conditions => ["post_id = ?", params[:post_id]])
  end
  
  def index
    set_title "Comments"
    
    if params[:format] == "json" || params[:format] == "xml"
      @comments = Comment.paginate(Comment.generate_sql(params).merge(:per_page => 25, :page => params[:page], :order => "id DESC"))
      respond_to_list("comments")
    else
      @posts = Post.paginate :order => "last_commented_at DESC", :conditions => "last_commented_at IS NOT NULL AND status <> 'deleted'", :per_page => 10, :page => params[:page]
      @posts = @posts.select {|x| x.can_be_seen_by?(@current_user)}
    end
  end
  
  def vote
    @comment = Comment.find(params[:id])

    begin
      if params[:score] == "down"
        @comment.vote!(@current_user, -1)
      else
        @comment.vote!(@current_user, 1)
      end

      respond_to_success("Vote saved", {:action => "index"}, :api => {:score => @comment.score})
    rescue Comment::VotingError => x
      respond_to_error(x.message, {:action => "index"}, :status => 423, :api => {:id => @comment.id})
    end
  end

  def search
    if params[:query]
      if params[:query] =~ /^user:(.+)$/
        user = User.find_by_name($1)
        if user
          @comments = Comment.paginate :order => "id desc", :per_page => 30, :conditions => ["user_id = ?", user.id], :page => params[:page]
        else
          @comments = Comment.paginate :per_page => 30, :page => params[:page], :conditions => "false"
        end
      else
        query = params[:query].scan(/\S+/).join(" & ")
        @comments = Comment.paginate :order => "id desc", :per_page => 30, :conditions => ["text_search_index @@ plainto_tsquery(?)", query], :page => params[:page]
      end
    else
      @comments = Comment.paginate :per_page => 30, :conditions => "FALSE", :page => params[:page]
    end
    
    respond_to_list("comments")
  end
end
