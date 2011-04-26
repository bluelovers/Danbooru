class AdminController < ApplicationController
  layout "default"
  helper :user, :post
  before_filter :admin_only, :except => :dashboard
  before_filter :janitor_only, :only => :dashboard

  def index
    set_title "Admin"
  end
  
  def dashboard
    @dashboard = Dashboard.new(params[:min_date] || 2.days.ago.to_date, params[:max_level] || 20)
  end
  
  def new_batch_alias_and_implication
  end
  
  def create_batch_alias_and_implication
    @creator = BatchAliasAndImplicationCreator.new(params[:batch][:text], @current_user.id, params[:batch][:forum_id])
    ActiveRecord::Base.transaction do
      @creator.process!
    end
    
    flash[:notice] = "Batch queued"
    redirect_to :controller => "job_task", :action => "index"
    
  rescue => x
    flash.now[:notice] = x.to_s
    render :action => "new_batch_alias_and_implication"
  end

  def edit_user
    if request.post?
      @user = User.find_by_name(params[:user][:name])
      if @user.nil?
        flash[:notice] = "User not found"
        redirect_to :action => "edit_user"
        return
      end
      @user.level = params[:user][:level]

      if @user.save
        flash[:notice] = "User updated"
        redirect_to :action => "edit_user"
      else
        render_error(@user)
      end
    end
  end

  def reset_password
    if request.post?
      @user = User.find_by_name(params[:user][:name])
      
      if @user
        new_password = @user.reset_password
        flash[:notice] = "Password reset to #{new_password}"
        
        unless @user.email.blank?
          UserMailer.deliver_new_password(@user, new_password)
        end
      else
        flash[:notice] = "That account does not exist"
        redirect_to :action => "reset_password"
      end
    else
      @user = User.new
    end
  end
end
