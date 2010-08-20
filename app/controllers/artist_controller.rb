class ArtistController < ApplicationController
  layout "default"

  before_filter :mod_only, :only => [:ban]
  before_filter :member_only, :only => [:create, :update, :destroy]
  helper :post, :wiki

  def preview
    render :inline => "<h4>Preview</h4><%= format_text(params[:artist][:notes]) %>"
  end
  
  def ban
    @artist = Artist.find(params[:id])

    if request.post?
      @artist.ban!(@current_user)
      flash[:notice] = "Artist has been banned"
      redirect_to :action => "show", :id => @artist.id
    end
  end

  def destroy
    @artist = Artist.find(params[:id])
    
    if request.post?
      @artist.update_attributes(:is_active => false, :updater_id => @current_user.id)
      respond_to_success("Artist deleted", :action => "index", :page => params[:page])
    end
  end

  def update
    if request.post?
      artist = Artist.find(params[:id])
      artist_by_name = Artist.find_by_name(params[:artist][:name])

      if artist_by_name && artist_by_name.id != artist.id
        params[:artist].delete(:name)
        artist.update_attribute(:is_active, false)
        artist = artist_by_name
        artist.is_active = true
      end

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

        post = Post.find_by_tags("source:http* #{params[:name]}", :limit => 1).first
        unless post == nil || post.source.blank?
          @artist.urls = post.source
        end
      end

      if params[:other_names]
        @artist.other_names = params[:other_names]
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
    if params[:order] == "date"
      order = "updated_at DESC"
    else
      order = "name"
    end
    
    limit = (params[:limit] || 50).to_i

    @artists = Artist.paginate(Artist.generate_sql(params).merge(:per_page => limit, :page => params[:page], :order => order))
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

  def check_name
    @artist = Artist.find_by_name(params[:name])
    
    render :update do |page|
      page.show "name-check-results"

      if @artist
        page.select("#name-check-results td").first.update("This artist already exists: " + link_to(h(params[:name]), {:action => "show", :name => params[:name]}, :target => "_blank"))
      else
        page.select("#name-check-results td").first.update("This artist does not exist")
      end
    end
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
