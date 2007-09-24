class NoteController < ApplicationController
  layout 'default', :only => [:index, :history, :search]
  before_filter :member_only, :only => [:destroy, :update, :revert]
  verify :method => :post, :only => [:update, :revert, :destroy]
  helper :post

  def search
    if params[:query]
      hits = NOTE_INDEX.search("body:#{params[:query]}").hits
      @pages = Paginator.new(:note, hits.size, 25, params[:page])
      @notes = hits.map {|x| Note.find(NOTE_INDEX[x.doc][:id])}
    end
  end

  def index
    set_title "Notes"
    
    if params[:post_id]
      @pages, @posts = paginate :posts, :order => "last_noted_at DESC", :conditions => ["id = ?", params[:post_id]], :per_page => 100
    else
      @pages, @posts = paginate :posts, :order => "last_noted_at DESC", :conditions => "last_noted_at IS NOT NULL", :per_page => 12
    end

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @posts.map {|x| x.notes}.flatten.to_xml(:root => "notes")}
      fmt.js {render :json => @posts.map {|x| x.notes}.flatten.to_json}
    end
  end

  def history
    set_title "Note History"

    if params[:id]
      @pages = Paginator.new self, NoteVersion.count(["note_id = ?", params[:id]]), 25, params[:page]
      @notes = NoteVersion.find(:all, :order => "id desc", :limit => @pages.items_per_page, :offset => @pages.current.offset, :conditions => ["note_id = ?", params[:id]])
    elsif params[:post_id]
      @pages = Paginator.new self, NoteVersion.count(["post_id = ?", params[:post_id]]), 50, params[:page]
      @notes = NoteVersion.find(:all, :order => "id desc", :conditions => ["post_id = ?", params[:post_id]])
    else
      @pages = Paginator.new self, NoteVersion.count, 25, params[:page]
      @notes = NoteVersion.find(:all, :order => "id desc", :limit => @pages.items_per_page, :offset => @pages.current.offset)
    end
  end

  def revert
    note = Note.find(params[:id])

    if note.locked?
      flash[:notice] = "This post is locked and notes cannot be altered"
      redirect_to :action => "history", :id => note.id
      return
    end

    note.revert_to(params[:version])
    note.ip_addr = request.remote_ip

    if note.save_without_revision
      flash[:notice] = "Note reverted"
      redirect_to :action => "history", :id => note.id
    else
      render_error(note)
    end
  end

  def update
    if params[:note][:post_id]
      note = Note.new(:post_id => params[:note][:post_id])
    else
      note = Note.find(params[:id])
    end

    if note.locked?
      render :json => {:success => false, :reason => "post is locked"}.to_json, :status => 500
      return
    end

    note.attributes = params[:note]
    note.user_id = @current_user.id
    note.ip_addr = request.remote_ip

    if note.save
      render :json => {:success => true, :new_id => note.id, :old_id => params[:id].to_i, :formatted_body => note.formatted_body}.to_json
    else
      render_error(note)
    end
  end
end
