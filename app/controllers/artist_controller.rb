class ArtistController < ApplicationController
  layout "default"

  before_filter :member_only, :only => [:create, :update, :destroy]
  helper :post, :wiki

  def destroy
    @artist = Artist.find(params[:id])
    @artist.destroy

    respond_to_success("Artist deleted", :action => "index", :params => params[:page])
  end

  def update
    if request.post?
      if params[:commit] == "Cancel"
        redirect_to :action => "show", :id => params[:id]
        return
      end

      artist = Artist.find(params[:id])
      artist.update_attributes(params[:artist].merge(:updater_ip_addr => request.remote_ip, :updater_id => @current_user.id))

      if artist.errors.empty?
        respond_to_success("Artist updated", :action => "show", :id => artist.id)
      else
        respond_to_error(artist, :action => "edit", :id => artist.id)
      end
    else
      @artist = Artist.find(params["id"])
    end
  end

  def create
    if request.post?
      artist = Artist.create(params[:artist].merge(:updater_ip_addr => request.remote_ip, :updater_id => @current_user.id))

      if artist.errors.empty?
        respond_to_success("Artist created", :action => "show", :id => artist.id)
      else
        respond_to_error(artist, :action => "add", :alias_id => params[:alias_id])
      end
    else
      @artist = Artist.new

      if params[:name]
        @artist.name = params[:name]

        post = Post.find(:first, :conditions => ["id IN (SELECT post_id FROM posts_tags WHERE tag_id = (SELECT id FROM tags WHERE name = ?)) AND source LIKE 'http%'", params[:name]])
        unless post == nil || post.source.blank?
          @artist.urls = post.source
        end
      end

      if params[:alias_id]
        @artist.alias_id = params[:alias_id]
      end
    end
  end

  def index
    if params[:name]
      @artists = Artist.paginate Artist.generate_sql(params[:name]).merge(:per_page => 50, :page => params[:page], :order => "name")
    elsif params[:url]
      @artists = Artist.paginate Artist.generate_sql(params[:url]).merge(:per_page => 50, :page => params[:page], :order => "name")
    else
      if params[:order] == "date"
        order = "updated_at DESC"
      else
        order = "name"
      end

      @artists = Artist.paginate :order => order, :per_page => 25, :page => params[:page]
    end

    respond_to_list("artists")
  end

  def show
    if params[:name]
      @artist = Artist.find_by_name(params[:name])
    else
      @artist = Artist.find(params[:id])
    end

    if @artist.nil?
      redirect_to :action => "create", :name => params[:name]
    else
      redirect_to :controller => "wiki", :action => "show", :title => @artist.name
    end
  end
end
