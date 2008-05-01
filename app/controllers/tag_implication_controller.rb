class TagImplicationController < ApplicationController
  layout "default"
  before_filter :admin_only, :only => [:update]
  before_filter :member_only, :only => [:create]
  verify :method => :post, :only => [:create, :update]

  def create
    ti = TagImplication.new(params[:tag_implication].merge(:is_pending => true))

    if ti.save
      flash[:notice] = "Tag implication created"
    else
      flash[:notice] = "Error: " + ti.errors.full_messages.join(", ")
    end

    redirect_to :action => "index"
  end

  def update
    ids = params[:implications].keys

    case params[:commit]
    when "Delete"
      ids.each {|x| TagImplication.find(x).destroy_and_notify(@current_user, params[:reason])}
      
      flash[:notice] = "Tag implications deleted"
      redirect_to :action => "index"

    when "Approve"
      ids.each {|x| TagImplication.find(x).approve(@current_user.id, request.remote_ip)}

      flash[:notice] = "Tag implications approved"
      redirect_to :action => "index"
    end
  end

  def index
    set_title "Tag Implications"
    
    if params[:commit] == "Search Aliases"
      redirect_to :controller => "tag_alias", :action => "index", :query => params[:query]
      return
    end
    
    if params[:query]
      name = "%" + params[:query].to_escaped_for_sql_like + "%"
      @implications = TagImplication.paginate :order => "is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)", :per_page => 20, :conditions => ["predicate_id IN (SELECT id FROM tags WHERE name ILIKE ? ESCAPE '\\\\') OR consequent_id IN (SELECT id FROM tags WHERE name ILIKE ? ESCAPE '\\\\')", name, name], :page => params[:page]
    else
      @implications = TagImplication.paginate :order => "is_pending DESC, (SELECT name FROM tags WHERE id = tag_implications.predicate_id), (SELECT name FROM tags WHERE id = tag_implications.consequent_id)", :per_page => 20, :page => params[:page]
    end

    respond_to_list("implications")
  end
end
