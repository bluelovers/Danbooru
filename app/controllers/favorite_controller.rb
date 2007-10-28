class FavoriteController < ApplicationController
  layout "default"
  before_filter :jailed_only, :only => [:create, :destroy]
  verify :method => :post, :only => [:create, :destroy]
  helper :post
  
  def show
    @user = User.find(params[:id])
    set_title "#{@user.pretty_name}'s Favorites"
    
    if hide_unsafe_posts?
      @pages, @posts = paginate :posts, :per_page => 16, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ? AND posts.rating = 's' AND posts.is_pending = FALSE", params["id"]], :select => "posts.*"
    else
      @pages, @posts = paginate :posts, :per_page => 16, :order => "favorites.id DESC", :joins => "JOIN favorites ON posts.id = favorites.post_id", :conditions => ["favorites.user_id = ?", params["id"]], :select => "posts.*"
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.to_xml(:root => "posts")}
      fmt.js {render :json => @posts.to_json}
      fmt.atom {render :action => "show_atom.rxml", :layout => false}
    end
  end

  def index
    @users = User.find(:all, :order => "lower(name)", :conditions => "EXISTS (SELECT favorites.* FROM favorites WHERE favorites.user_id = users.id)")
  end
  
  def create
    begin
      @current_user.add_favorite(params[:id])
      p = Post.find(:first, :conditions => ["id = ?", params[:id]], :select => "posts.score, posts.id")

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Post added to favorites"; redirect_to(:controller => "post", :action => "show", :id => params[:id])}
        fmt.js do
          favorited_users = p.favorited_by.map {|x| '<a href="/favorite/show/%s">%s</a>' % [x.id, ERB::Util.h(x.name)]}
          if favorited_users.empty?
            favorited_users = "Favorited by: no one"
          else
            favorited_users = "Favorited by: #{favorited_users.join(', ')}"
          end

          render :json => {:success => true, :score => p.score, :post_id => params[:id], :favorited => favorited_users}.to_json
        end
        fmt.xml {render :xml => {:success => true, :score => p.score, :post_id => params[:id]}.to_xml(:root => "response")}
      end
    rescue User::AlreadyFavoritedError
      respond_to do |fmt|
        fmt.html {flash[:notice] = "You've already voted for this post"; redirect_to(:controller => "post", :action => "show", :id => params[:id])}
        fmt.js {render :json => {:success => false, :reason => "already voted"}.to_json, :status => 409}
        fmt.xml {render :xml => {:success => false, :reason => "already voted"}.to_xml(:root => "response"), :status => 409}
      end
    end
  end
  
  def destroy
    @current_user.delete_favorite(params[:id])

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Post deleted from your favorites"; redirect_to(:controller => "post", :action => "show", :id => params[:id])}
      fmt.js {render :json => {:success => true, :post_id => params[:id].to_i}.to_json}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
    end
  end
end
