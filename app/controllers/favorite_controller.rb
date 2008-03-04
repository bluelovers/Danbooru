class FavoriteController < ApplicationController
  layout "default"
  before_filter :blocked_only, :only => [:create, :destroy]
  verify :method => :post, :only => [:create, :destroy]
  verify :params => :id, :only => [:create]
  helper :post

  def index
    @users = User.find(:all, :order => "lower(name)", :conditions => "EXISTS (SELECT favorites.* FROM favorites WHERE favorites.user_id = users.id)")
  end
  
  def create
    begin
      @post = Post.find(:first, :conditions => ["id = ?", params[:id]], :select => "posts.score, posts.id")
      @current_user.add_favorite(@post.id)

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post added to favorites"; redirect_to(:controller => "post", :action => "index", :tags => "fav:#{@current_user.name}")}
        fmt.json do
          favorited_users = @post.favorited_by.map {|x| %{<a href="/post/index/fav%3A#{CGI.escapeHTML(x.name)}">#{CGI.escapeHTML(x.name)}</a>}}
          if favorited_users.empty?
            favorited_users = "Favorited by: no one"
          else
            favorited_users = "Favorited by: #{favorited_users.join(', ')}"
          end

          render :json => {:success => true, :score => @post.score + 1, :post_id => @post.id, :favorited => favorited_users}.to_json
        end
        fmt.xml {render :xml => {:success => true, :score => @post.score + 1, :post_id => @post.id}.to_xml(:root => "response")}
      end
    rescue User::AlreadyFavoritedError
      respond_to_error("Already favorited", :controller => "post", :action => "show", :id => params[:id])
    end
  end
  
  def destroy
    @post = Post.find(params[:id])
    @current_user.delete_favorite(@post.id)

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Post deleted from your favorites"; redirect_to(:controller => "post", :action => "show", :id => @post.id)}
      fmt.json do
        favorited_users = @post.favorited_by.map {|x| %{<a href="/post/index/fav%3A#{CGI.escapeHTML(x.name)}">#{CGI.escapeHTML(x.name)}</a>}}
        if favorited_users.empty?
          favorited_users = "Favorited by: no one"
        else
          favorited_users = "Favorited by: #{favorited_users.join(', ')}"
        end
        
        render :json => {:success => true, :post_id => @post.id, :favorited => favorited_users, :score => @post.score - 1}.to_json
      end
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
    end
  end
end
