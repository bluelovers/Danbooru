class PostTagHistoryController < ApplicationController
  layout 'default'
  before_filter :member_only
  
  def index
    joins, conds = PostTagHistory.generate_sql(params)
    @pages, @changes = paginate :post_tag_histories, :order => "id DESC", :per_page => 20, :conditions => conds, :joins => joins, :select => "post_tag_histories.*"
  end
  
  def revert
    @change = PostTagHistory.find(params[:id])
    @post = Post.find(@change.post_id)
    
    if request.post?
      if params[:commit] == "Yes"
        @post.update_attributes(:updater_ip_addr => request.remote_ip, :updater_user_id => @current_user.id, :tags => @change.tags)      
        flash[:notice] = "Tags reverted"
      end

      redirect_to :controller => "post", :action => "show", :id => @post.id
    end
  end  
end
