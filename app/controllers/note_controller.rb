class NoteController < ApplicationController
  layout 'default', :only => [:index, :history, :search]
  before_filter :member_only, :only => [:destroy, :update, :revert]
  verify :method => :post, :only => [:update, :revert, :destroy]
  helper :post

  def search
    if params[:query]
      query = params[:query].scan(/\S+/).join(" & ")
      @notes = Note.paginate :order => "id asc", :per_page => 25, :conditions => ["text_search_index @@ plainto_tsquery(?)", query], :page => params[:page]

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
      @posts = Post.paginate :order => "last_noted_at DESC", :conditions => ["id = ?", params[:post_id]], :per_page => 100, :page => params[:page]
    else
      @posts = Post.paginate :order => "last_noted_at DESC", :conditions => "last_noted_at IS NOT NULL", :per_page => 16, :page => params[:page]
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
      @notes = NoteVersion.paginate(:page => params[:page], :per_page => 25, :order => "id DESC", :conditions => ["note_id = ?", params[:id]])
    elsif params[:post_id]
      @notes = NoteVersion.paginate(:page => params[:page], :per_page => 50, :order => "id DESC", :conditions => ["post_id = ?", params[:post_id]])
    elsif params[:user_id]
      @notes = NoteVersion.paginate(:page => params[:page], :per_page => 50, :order => "id DESC", :conditions => ["user_id = ?", params[:user_id]])
    else
      @notes = NoteVersion.paginate(:page => params[:page], :per_page => 25, :order => "id DESC")
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
        fmt.xml {render :xml => {:success => true, :new_id => note.id, :old_id => params[:id].to_i, :formatted_body => HTML5Sanitizer::hs(note.formatted_body)}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true, :new_id => note.id, :old_id => params[:id].to_i, :formatted_body => HTML5Sanitizer::hs(note.formatted_body)}.to_json}
      end
    else
      render_error(note)
    end
  end
end
