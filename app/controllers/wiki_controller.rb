class WikiController < ApplicationController
  layout 'default'
  before_filter :member_only, :only => [:update, :create, :edit, :revert]
  before_filter :mod_only, :only => [:lock, :unlock, :destroy, :rename]
  verify :method => :post, :only => [:lock, :unlock, :destroy, :update, :create, :revert]

  def destroy
    page = WikiPage.find_page(params[:title])
    page.destroy

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Page deleted"; redirect_to(:action => "show", :title => params[:title])}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
      fmt.js {render :json => {:success => true}.to_json}
    end
  end

  def lock
    page = WikiPage.find_page(params[:title])
    page.lock!

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Page locked"; redirect_to(:action => "show", :title => params[:title])}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
      fmt.js {render :json => {:success => true}.to_json}
    end
  end

  def unlock
    page = WikiPage.find_page(params["title"])
    page.unlock!

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Page unlocked"; redirect_to(:action => "show", :title => params[:title])}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
      fmt.js {render :json => {:success => true}.to_json}
    end
  end

  def index
    set_title "Wiki"
    
    if params[:order] == "date"
      order = "updated_at"
    else
      order = "lower(title)"
    end
    
    limit = params[:limit] || 25

    if params[:query]
      query = params[:query].scan(/\S+/).join(" & ")
      @pages, @wiki_pages = paginate :wiki_pages, :order => order, :per_page => limit, :conditions => ["text_search_index @@ plainto_tsquery(?)", query]
    else
      @pages, @wiki_pages = paginate :wiki_pages, :order => order, :per_page => limit
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @wiki_pages.to_xml(:root => "wiki_pages")}
      fmt.js {render :json => @wiki_pages.to_json}
    end
  end

  def preview
    render :inline => "<%= wikilize(params[:body]) %>"
  end

  def add
    @wiki_page = WikiPage.new
    @wiki_page.title = params[:title]
  end

  def create
    page = WikiPage.create(params[:wiki_page].merge(:ip_addr => request.remote_ip, :user_id => session[:user_id]))
    if page.errors.empty?
      respond_to do |fmt|
        location = url_for(:action => "show", :title => page.title)
        fmt.html {flash[:notice] = "New wiki page created"; redirect_to(location)}
        fmt.xml {render :xml => {:success => true, :location => location}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true, :location => location}.to_json}
      end
    else
      respond_to do |fmt|
        error = page.errors.full_messages.join(", ")
        fmt.html {flash[:notice] = "Error: #{error}"; redirect_to(:action => "index")}
        fmt.xml {render :xml => {:success => false, :reason => error}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
      end
    end
  end

  def update
    @page = WikiPage.find_page(params[:title] || params[:wiki_page][:title])

    if @page.is_locked?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "This page is locked and cannot be edited"; redirect_to(:action => "show", :title => params[:title])}
        fmt.xml {render :xml => {:success => false, :reason => "page locked"}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => false, :reason => "page locked"}.to_json}
      end
    else
      if @page.update_attributes(params[:wiki_page].merge(:ip_addr => request.remote_ip, :user_id => session[:user_id]))
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Wiki page updated"; redirect_to(:action => "show", :title => @page.title)}
          fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
          fmt.js {render :json => {:success => true}.to_json}
        end
      else
        respond_to do |fmt|
          error = @page.errors.full_messages.join(", ")
          fmt.html {flash[:notice] = "Error: #{error}"; redirect_to(:action => "index")}
          fmt.xml {render :xml => {:success => false, :reason => h(error)}.to_xml(:root => "response"), :status => 500}
          fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
        end
      end
    end
  end

  def show
    if params[:title] == nil
      render :text => "no title specified"
      return
    end

    tag_type = Tag.find_by_name(params[:title]).tag_type rescue nil

    if tag_type == Tag.types[:artist]
      artist = Artist.find_by_name(params[:title])

      if artist == nil
        respond_to do |fmt|
          fmt.html {redirect_to :controller => "artist", :action => "add", :name => params[:title]}
          fmt.xml {render :xml => {:success => false, :reason => "artist type"}.to_xml(:root => "response"), :status => 500}
          fmt.js {render :json => {:success => false, :reason => "artist type"}.to_json, :status => 500}
        end
      else
        respond_to do |fmt|
          fmt.html {redirect_to :controller => "artist", :action => "show", :id => artist.id}
          fmt.xml {render :xml => {:success => false, :reason => "artist type", :artist_id => artist.id}.to_xml(:root => "response"), :status => 500}
          fmt.js {render :json => {:success => false, :reason => "artist type", :artist_id => artist.id}.to_json, :status => 500}
        end
      end
    end

    @page = WikiPage.find_page(params[:title], params[:version])
    set_title params[:title].tr("_", " ")
  end

  def edit
    if params[:title] == nil
      render :text => "no title specified"
    else
      @wiki_page = WikiPage.find_page(params[:title], params[:version])

      if @wiki_page == nil
        redirect_to :action => "add", :title => params[:title]
      end
    end
  end

  def revert
    @page = WikiPage.find_page(params[:title])

    if @page.is_locked?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "This page is locked and cannot be edited"; redirect_to(:action => "show", :title => params[:title])}
        fmt.xml {render :xml => {:success => false, :reason => "page locked"}.to_xml(:root => "response"), :status => 409}
        fmt.js {render :json => {:success => false, :reason => "page locked"}.to_json, :status => 409}
      end
    else
      @page.revert_to(params[:version])
      @page.ip_addr = request.remote_ip
      @page.user_id = @current_user.id

      if @page.save
        respond_to do |fmt|
          fmt.html {flash[:notice] = "Wiki page was reverted"; redirect_to(:action => "show", :title => @page.title)}
          fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
          fmt.js {render :json => {:success => true}.to_json}
        end
      else
        respond_to do |fmt|
          error = @page.errors.full_messages.join(", ")
          fmt.html {flash[:notice] = "Error: #{error}"; redirect_to(:action => "index")}
          fmt.xml {render :xml => {:success => false, :reason => h(error)}.to_xml(:root => "response"), :status => 500}
          fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
        end
      end
    end
  end

  def recent_changes
    set_title "Recent Changes"

    @pages, @wiki_pages = paginate :wiki_page_versions, :order => "updated_at DESC", :per_page => (params[:per_page] || 25)
    
    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @wiki_pages.to_xml(:root => "wiki_pages")}
      fmt.js {render :json => @wiki_pages.to_json}
    end
  end

  def history
    set_title "Wiki History"

    @wiki_pages = WikiPageVersion.find(:all, :conditions => ["title = ?", params[:title]], :order => "updated_at DESC")

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @wiki_pages.to_xml(:root => "wiki_pages")}
      fmt.js {render :json => @wiki_pages.to_json}
    end
  end

  def diff
    set_title "Wiki Diff"

    if params[:redirect]
      redirect_to :action => "diff", :title => params[:title], :from => params[:from], :to => params[:to]
      return
    end

    if params[:title] == nil
      flash[:notice] = "No title was specificed"
      redirect_to :action => "index"
      return
    end

    @oldpage = WikiPage.find_page(params[:title], params[:from])
    @difference = @oldpage.diff(params[:to])
  end
  
  def rename
    @wiki_page = WikiPage.find_page(params[:title])
  end
end
