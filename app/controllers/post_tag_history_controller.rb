class PostTagHistoryController < ApplicationController
  layout 'default'
  before_filter :member_only
  
  def index
    joins, conds = PostTagHistory.generate_sql(params)
    @changes = PostTagHistory.paginate :order => "id DESC", :per_page => 20, :conditions => conds, :joins => joins, :select => "post_tag_histories.*", :page => params[:page]
    @change_list = @changes.map { |c|
      { :change => c }.merge(c.tag_changes(c.previous))
    }
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
