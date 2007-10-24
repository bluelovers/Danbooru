class FlaggedPostController < ApplicationController
  layout 'default'

  def index
    if params[:user_id]
      @flagged_posts = FlaggedPost.find(:all, :conditions => ["user_id = ?", params[:user_id]], :order => "created_at desc")
    else
      @flagged_posts = FlaggedPost.find(:all, :order => "created_at desc", :limit => 50)
    end
  end
end
