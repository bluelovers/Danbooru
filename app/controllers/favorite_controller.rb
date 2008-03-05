class FavoriteController < ApplicationController
  layout "default"
  before_filter :blocked_only, :only => [:create, :destroy]
  verify :method => :post, :only => [:create, :destroy]
  verify :params => :id, :only => [:create]
  helper :post

  def create
    begin
      @post = Post.find(:first, :conditions => ["id = ?", params[:id]], :select => "posts.score, posts.id")
      @current_user.add_favorite(@post.id)
      
      favorited_users = @post.favorited_by.map {|x| %{<a href="/post/index/fav%3A#{ERB::Util.u(x.name)}">#{CGI.escapeHTML(x.name)}</a>}}
      if favorited_users.empty?
        favorited_users = "no one"
      else
        favorited_users = favorited_users.join(', ')
      end
      respond_to_success("Post added", {:controller => "post", :action => "show", :id => @post.id}, :api => {:score => @post.score + 1, :post_id => @post.id, :favorited => favorited_users})
    rescue User::AlreadyFavoritedError
      respond_to_error("Already favorited", {:controller => "post", :action => "show", :id => params[:id]}, :status => 423)
    end
  end
  
  def destroy
    @post = Post.find(params[:id])
    @current_user.delete_favorite(@post.id)
    favorited_users = @post.favorited_by.map {|x| %{<a href="/post/index/fav%3A#{ERB::Util.u(x.name)}">#{CGI.escapeHTML(x.name)}</a>}}
    if favorited_users.empty?
      favorited_users = "Favorited by: no one"
    else
      favorited_users = "Favorited by: #{favorited_users.join(', ')}"
    end
    respond_to_success("Post removed", {:controller => "post", :action => "show", :id => @post.id}, :api => {:score => @post.score - 1, :post_id => @post.id, :favorited => favorited_users})
  end
end
