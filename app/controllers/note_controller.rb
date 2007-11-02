class NoteController < ApplicationController
  layout 'default', :only => [:index, :history, :search]
  before_filter :member_only, :only => [:destroy, :update, :revert]
  verify :method => :post, :only => [:update, :revert, :destroy]
  helper :post

  def search
    if params[:query]
      query = params[:query].scan(/\S+/).join(" & ")
      @pages, @notes = paginate :notes, :order => "id asc", :per_page => 25, :conditions => ["text_search_index @@ to_tsquery(?)", query]

      respond_to do |fmt|
        fmt.html
        fmt.xml {render :xml => @notes.to_xml(:root => "notes")}
        fmt.js {render :json => @notes.to_json}
      end
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
      @pages = Paginator.new self, NoteVersion.count(["note_id = ?", params[:id].to_i]), 25, params[:page]
      @notes = NoteVersion.find(:all, :order => "id desc", :limit => @pages.items_per_page, :offset => @pages.current.offset, :conditions => ["note_id = ?", params[:id].to_i])
    elsif params[:post_id]
      @pages = Paginator.new self, NoteVersion.count(["post_id = ?", params[:post_id].to_i]), 50, params[:page]
      @notes = NoteVersion.find(:all, :order => "id desc", :conditions => ["post_id = ?", params[:post_id].to_i], :offset => @pages.current.offset, :limit => @pages.items_per_page)
    elsif params[:user_id]
      @pages = Paginator.new self, NoteVersion.count(["user_id = ?", params[:user_id]]), 50, params[:page]
      @notes = NoteVersion.find(:all, :order => "notes.id desc, note_versions.version desc", :joins => "JOIN notes ON notes.id = note_versions.note_id", :select => "note_versions.*", :conditions => ["notes.user_id = ?", params[:user_id]], :limit => @pages.items_per_page, :offset => @pages.current.offset)
    else
      @pages = Paginator.new self, NoteVersion.count, 25, params[:page]
      @notes = NoteVersion.find(:all, :order => "id desc", :limit => @pages.items_per_page, :offset => @pages.current.offset)
    end
    
    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @notes.to_xml(:root => "notes")}
      fmt.js {render :json => @notes.to_json}
    end
  end

  def revert
    note = Note.find(params[:id])

    if note.locked?
      respond_to do |fmt|
        fmt.html {flash[:notice] = "This post is locked and notes cannot be altered"; redirect_to(:action => "history", :id => note.id)}
        fmt.xml {render :xml => {:success => false, :reason => "post is locked"}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :xml => {:success => false, :reason => "post is locked"}.to_json, :status => 500}
      end
      return
    end

    note.revert_to(params[:version])
    note.ip_addr = request.remote_ip
    note.user_id = @current_user.id

    if note.save
      respond_to do |fmt|
        fmt.html {flash[:notice] = "Note reverted"; redirect_to(:action => "history", :id => note.id)}
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
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
      respond_to do |fmt|
        fmt.xml {render :xml => {:success => false, :reason => "post is locked"}.to_xml(:root => "response"), :status => 500}
        fmt.js {render :json => {:success => false, :reason => "post is locked"}.to_json, :status => 500}
      end
      return
    end

    note.attributes = params[:note]
    note.user_id = @current_user.id
    note.ip_addr = request.remote_ip

    if note.save
      respond_to do |fmt|
        fmt.xml {render :xml => {:success => true, :new_id => note.id, :old_id => params[:id].to_i, :formatted_body => note.formatted_body}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true, :new_id => note.id, :old_id => params[:id].to_i, :formatted_body => note.formatted_body}.to_json}
      end
    else
      render_error(note)
    end
  end
end
