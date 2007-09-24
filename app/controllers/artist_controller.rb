class ArtistController < ApplicationController
  layout "default"

  before_filter :privileged_only, :only => [:destroy]
  before_filter :member_only, :only => [:update, :create]
  verify :method => :post, :only => [:destroy, :update, :create]
  helper :post

  def destroy
    @artist = Artist.find(params[:id])
    @artist.destroy

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Artist deleted"; redirect_to(:action => "index", :page => params[:page])}
      fmt.js
    end
  end

  def update
    if params[:commit] == "Cancel"
      redirect_to :action => "show", :id => params[:id]
      return
    end

    artist = Artist.find(params[:id])
    artist.update_attributes(params[:artist].merge(:updater_id => (@current_user ? @current_user.id : nil)))

    if artist.errors.empty?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Artist entry updated"; redirect_to(:action => "show", :id => artist.id)}
        fmt.xml {render :xml => {:sucess => true}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      errors = artist.errors.full_messages.join(", ")
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Error: " + errors; redirect_to(:action => "edit", :id => artist.id)}
        fmt.xml {render :xml => {:success => false, :reason => errors}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => false, :reason => errors}.to_json}
      end
    end
  end

  def create
    artist = Artist.create(params[:artist].merge(:updater_id => (@current_user ? @current_user.id : nil)))

    if artist.errors.empty?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Artist created"; redirect_to(:action => "show", :id => artist.id)}
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
        fmt.js {render :json > {:success => true}.to_json}
      end
    else
      errors = artist.errors.full_messages.join(", ")
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Error: " + errors; redirect_to(:action => "add", :alias_id => params[:alias_id])}
        fmt.xml {render :xml => {:success => false, :reason => errors}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => false, :reason => errors}.to_json}
      end
    end
  end

  def edit
    @artist = Artist.find(params["id"])
  end

  def add
    @artist = Artist.new

    if params[:name]
      @artist.name = params[:name]

      post = Post.find(:first, :conditions => ["id IN (SELECT post_id FROM posts_tags WHERE tag_id = (SELECT id FROM tags WHERE name = ?)) AND source LIKE 'http%'", params[:name]])
      unless post == nil || post.source.blank?
        @artist.url_b = post.source
      end
    end

    if params[:alias_id]
      @artist.alias_id = params[:alias_id]
    end
  end

  def index
    if params[:name]
      if params[:name] =~ /^http/
        @artists = Artist.find_all_by_url(params[:name])
      elsif params[:name] =~ /^[a-fA-F0-9]{32,32}$/
        @artists = Artist.find_all_by_md5(params[:name])
      else
        @pages, @artists = paginate :artists, :conditions => ["name LIKE ? ESCAPE '\\\\'", '%' + params[:name].to_escaped_for_sql_like + '%'], :order => "name", :per_page => 50
      end
    elsif params[:url]
      @artists = Artist.find_all_by_url(params[:url])
    elsif params[:md5]
      @artists = Artist.find_all_by_md5(params[:md5])
    else
      if params[:order] == "date"
        order = "updated_at DESC"
      else
        order = "name"
      end

      @pages, @artists = paginate :artists, :order => order, :per_page => 25
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @artists.to_xml(:root => "artists")}
      fmt.js {render :json => @artists.to_json}
    end
  end

  def show
    @artist = Artist.find(params[:id])
    @posts = Post.find_by_tags(@artist.name, :limit => 5, :order => "id desc", :hide_unsafe_posts => hide_unsafe_posts?)
  end
end
