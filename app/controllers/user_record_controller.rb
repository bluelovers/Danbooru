class UserRecordController < ApplicationController
  layout "default"
  before_filter :mod_only => [:create]
  before_filter :admin_only => [:destroy]
  
  def index
    if params[:user_id]
      @user = User.find(params[:user_id])
      @pages, @user_records = paginate :user_records, :per_page => 20, :order => "created_at desc", :conditions => ["user_id = ?", params[:user_id]]
    else
      @pages, @user_records = paginate :user_records, :per_page => 20, :order => "created_at desc"
    end
  end
  
  def create
    @user = User.find(params[:user_id])

    if request.post?
      @user_record = UserRecord.create(params[:user_record].merge(:user_id => params[:user_id], :reported_by => @current_user.id))
      flash[:notice] = "Record updated"
      redirect_to :action => "index", :user_id => @user.id
    end
  end
  
  def destroy
    if request.post?
      UserRecord.destroy(params[:id])
      flash[:notice] = "Record updated"
      redirect_to :action => "index", :user_id => params[:user_id]
    end
  end
end
