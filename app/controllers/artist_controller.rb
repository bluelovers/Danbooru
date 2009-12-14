class ArtistController < ApplicationController
  layout "default"

  before_filter :member_only, :only => [:create, :update, :destroy]
  helper :post, :wiki

  def preview
    render :inline => "<h4>Preview</h4><%= format_text(params[:artist][:notes]) %>"
  end

  def destroy
    @artist = Artist.find(params[:id])
    
    if request.post?
      if params[:commit] == "Yes"
        @artist.update_attributes(:is_active => false, :updater_id => @current_user.id)
        respond_to_success("Artist deleted", :action => "index", :page => params[:page])
      else
        redirect_to :action => "index", :page => params[:page]
      end
    end
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
        respond_to_error(artist, :action => "update", :id => artist.id)
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
        respond_to_error(artist, :action => "create", :alias_id => params[:alias_id])
      end
    else
      @artist = Artist.new

      if params[:name]
        @artist.name = params[:name]

        post = Post.find(:first, :conditions => ["tags_index @@ ? AND source LIKE 'http%'", "'" + params[:name] + "'"])
        unless post == nil || post.source.blank?
          @artist.urls = post.source
        end
      end

      if params[:alias_names]
        @artist.alias_names = params[:alias_names]
      end
      
      if params[:urls]
        @artist.urls = params[:urls]
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
    
    if @artist
      @posts = Post.find_by_tag_join(@artist.name, :limit => 6).select {|x| x.can_be_seen_by?(@current_user)}
    else
      redirect_to :action => "create", :name => params[:name]
    end
  end
  
  def history
    @artist = Artist.find(params[:id])
    @versions = ArtistVersion.paginate :order => "version desc", :per_page => 25, :page => params[:page], :conditions => ["artist_id = ?", @artist.id]
  end
  
  def recent_changes
    if params[:user_id]
      @updater_user = User.find(params[:user_id])
      @versions = ArtistVersion.paginate :order => "id desc", :per_page => 25, :page => params[:page], :conditions => ["user_id = ?", @updater_user.id]
    else
      @versions = ArtistVersion.paginate :order => "id desc", :per_page => 25, :page => params[:page]
    end
  end
end
