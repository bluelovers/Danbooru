class TagAliasController < ApplicationController
  layout "default"
  before_filter :admin_only, :only => [:update]
  before_filter :member_only, :only => [:create]
  verify :method => :post, :only => [:create, :update]

  def create
    TagAlias.create(params[:tag_alias].merge(:is_pending => true))

    flash[:notice] = "Tag alias created"
    redirect_to :action => "index"
  end

  def index
    set_title "Tag Aliases"
    
    if params[:query]
      name = "%" + params[:query].to_escaped_for_sql_like + "%"
      @aliases = TagAlias.paginate :order => "is_pending DESC, name", :per_page => 50, :conditions => ["name LIKE ? ESCAPE '\\\\' OR alias_id IN (SELECT id FROM tags WHERE name ILIKE ? ESCAPE '\\\\')", name, name]
    else
      @aliases = TagAlias.paginate :order => "is_pending DESC, name", :per_page => 50
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @aliases.to_xml(:root => "aliases")}
      fmt.js {render :json => @aliases.to_json}
    end
  end

  def update
    ids = params[:aliases].keys

    case params[:commit]
    when "Delete"
      ids.each {|x| TagAlias.destroy(x)}
      
      flash[:notice] = "Tag aliases deleted"
      redirect_to :action => "index"

    when "Approve"
      PostTagHistory.disable_versioning = true
      ids.each {|x| TagAlias.find(x).approve(@current_user.id, request.remote_ip)}
      PostTagHistory.disable_versioning = false

      flash[:notice] = "Tag aliases approved"
      redirect_to :action => "index"
    end
  end
end
