class FlaggedPostController < ApplicationController
  layout 'default'

  def index
    if params[:user_id]
      @pages, @flagged_posts = paginate :flagged_posts, :order => "created_at desc", :conditions => ["user_id = ?", params[:user_id]], :per_page => 20
    else
      @pages, @flagged_posts = paginate :flagged_posts, :order => "created_at desc", :per_page => 20
    end
  end
end
