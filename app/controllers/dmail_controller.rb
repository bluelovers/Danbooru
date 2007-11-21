class DmailController < ApplicationController
  before_filter :member_only
  layout "default"
  
  def auto_complete_for_dmail_to
    @users = User.find(:all, :order => "lower(name)", :conditions => ["name ilike ? escape '\\\\'", params[:dmail][:to] + "%"])
    render :layout => false, :text => "<ul>" + @users.map {|x| "<li>" + x.name + "</li>"}.join("") + "</ul>"
  end
  
  def compose
    @dmail = Dmail.new(:from_id => @current_user.id)
  end
  
  def create
    @dmail = Dmail.create(params[:dmail])
    
    if @dmail.errors.empty?
      User.update(@dmail.to_id, :has_mail => true)
      flash[:notice] = "Message sent to #{params[:dmail][:to]}"
      redirect_to :action => "inbox"
    else
      flash[:notice] = "Error: " + CGI.escapeHTML(@dmail.errors.full_messages.join(", "))
      redirect_to :action => "inbox"
    end
  end
  
  def inbox
    @pages, @dmails = paginate :dmails, :conditions => ["to_id = ?", @current_user.id], :order => "created_at desc", :per_page => 25
  end
  
  def sent
    @pages, @dmails = paginate :dmails, :conditions => ["from_id = ?", @current_user.id], :order => "created_at desc", :per_page => 25
  end
  
  def show
    @dmail = Dmail.find(params[:id])

    # TODO: Add refined access checking
    if @dmail.to_id != @current_user.id && @dmail.from_id != @current_user.id
      flash[:notice] = "Access denied"
      redirect_to :action => "inbox"
      return
    end

    @dmail.update_attribute(:has_seen, true)
    
    unless Dmail.exists?(["has_seen = false and to_id = ?", @current_user.id])
      @current_user.update_attribute(:has_mail, false)
    end
  end
  
  def destroy
    Dmail.find(params[:dmail].keys).each do |dmail|
      # TODO: Add refined access checking
      if dmail.to_id == @current_user.id
        dmail.destroy
      end
    end
    
    flash[:notice] = "Messages deleted"
    redirect_to :action => "inbox"
  end
end
