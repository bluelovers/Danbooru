class FavoriteController < ApplicationController
  layout "default"
  before_filter :blocked_only, :only => [:create, :destroy]
  verify :method => :post, :only => [:create, :destroy]
  helper :post

  def create
    begin
      @post = Post.find(:first, :conditions => ["id = ?", params[:id]], :select => "posts.score, posts.id")
      @current_user.add_favorite(@post.id)
      @post.reload
      
      respond_to_success("Post added", {:controller => "post", :action => "show", :id => @post.id}, :api => {:score => @post.score, :post_id => @post.id, :favorited_users => favorited_users_for_post(@post)})
    rescue User::FavoriteError => x
      respond_to_error(x.message, {:controller => "post", :action => "show", :id => params[:id]}, :status => 423)
    end
  end
  
  def destroy
    @post = Post.find(:first, :conditions => ["id = ?", params[:id]], :select => "posts.score, posts.id")
    @current_user.delete_favorite(@post.id)
    @post.reload
    respond_to_success("Post removed", {:controller => "post", :action => "show", :id => @post.id}, :api => {:score => @post.score, :post_id => @post.id, :favorited_users => favorited_users_for_post(@post)})
  end
  
  def list_users
    @post = Post.find(params[:id])
    
    respond_to do |fmt|
      fmt.json do
        render :json => {:favorited_users => @post.favorited_by.map(&:name).join(",")}.to_json
      end
      fmt.xml do
        builder = Builder::XmlMarkup.new(:indent => 2)
        builder.instruct!
        code = builder.favorites(:post_id => @post.id) do
          @post.favorited_by.each do |user|
            builder.user(:name => user.name)
          end
        end
        render :xml => code
      end
    end
  end
  
protected
  def favorited_users_for_post(post)
    post.favorited_by.map {|x| x.name}.uniq.join(",")
  end
end
