class ArtistController < ApplicationController
  layout "default"

  before_filter :mod_only, :only => [:destroy]
  verify :method => :post, :only => [:destroy, :update, :create]

# Parameters
# - id: the ID number of the artist to delete
  def destroy
    artist = Artist.find(params[:id])
    artist.destroy

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Artist deleted"; redirect_to(:action => "index", :page => params[:page])}
    end
  end

# Parameters
# - id: the ID number of the artist to update
# - artist[name]: the artist's name
# - artist[url_a]: base URL of the artist's home page
# - artist[url_b]: base URL of the site storing the artist's images
# - artist[url_c]: extra base URL
# - artist[alias]: artist this artist is an alias for
# - artist[group]: artist group this artist belongs to
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
        fmt.xml {render :xml => {:sucess => true}.to_xml("response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    else
      errors = artist.errors.full_messages.join(", ")
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Error: " + errors; redirect_to(:action => "edit", :id => artist.id)}
        fmt.xml {render :xml => {:success => false, :reason => errors}.to_xml("response")}
        fmt.js {render :json => {:success => false, :reason => errors}.to_json}
      end
    end
  end

# Parameters
# - artist[name]: the artist's name
# - artist[url_a]: base URL of the artist's home page
# - artist[url_b]: base URL of the site storing the artist's images
# - artist[url_c]: extra base URL
# - artist[alias]: artist this artist is an alias for
# - artist[group]: artist group this artist belongs to
  def create
    artist = Artist.create(params[:artist].merge(:updater_id => (@current_user ? @current_user.id : nil)))

    if artist.errors.empty?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Artist created"; redirect_to(:action => "show", :id => artist.id)}
        fmt.xml {render :xml => {:success => true}.to_xml("response")}
        fmt.js {render :json > {:success => true}.to_json}
      end
    else
      errors = artist.errors.full_messages.join(", ")
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Error: " + errors; redirect_to(:action => "add", :alias_id => params[:alias_id])}
        fmt.xml {render :xml => {:success => false, :reason => errors}.to_xml("response")}
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

# Parameters
# - name: the artist's name. If you supply a URL beginning with http, Danbooru will search against the URL database. Danbooru will automatically progressively shorten the supplied URL until either a match is found or the string is too short (so you can supply direct links to images and Danbooru will find a match).
  def index
    if params[:name]
      name = params[:name]

      if name =~ /^http/
        @artists = []

        while @artists.empty? && name.size > 10
          escaped_name = name.gsub(/'/, "''").gsub(/\\/, '\\\\')
          @pages, @artists = paginate :artists, :conditions => "url_a LIKE '#{escaped_name}%' ESCAPE '\\\\' OR url_b LIKE '#{escaped_name}%' ESCAPE '\\\\' OR url_c LIKE '#{escaped_name}%' ESCAPE '\\\\'", :order => "name", :per_page => 25
          name = File.dirname(name)
        end
      else
        name = name.gsub(/'/, "''").gsub(/\\/, '\\\\')
        @pages, @artists = paginate :artists, :conditions => "name LIKE '%#{name}%' ESCAPE '\\\\'", :order => "name", :per_page => 25
      end
    else
      if params[:order] == "date"
        order = "updated_at DESC"
      else
        order = "name"
      end

      @pages, @artists = paginate :artists, :conditions => "name <> ''", :order => order, :per_page => 25
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @artists.to_xml}
      fmt.js {render :json => @artists.to_json}
    end
  end

  def show
    @artist = Artist.find(params[:id])
  end
end
