class PostAppealController < ApplicationController
  layout "default"
  helper :post, :admin
  
  def index
    @posts = Post.paginate(:page => params[:page], :joins => "JOIN post_appeals ON post_appeals.post_id = posts.id", :select => "posts.*", :conditions => ["posts.status <> ? and post_appeals.created_at >= ?", "active", 14.days.ago], :order => "post_appeals.id DESC")
  end
end
