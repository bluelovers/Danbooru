class AdminController < ApplicationController
  layout "default"
  before_filter :admin_only, :except => :dashboard
  before_filter :mod_only, :only => :dashboard

  def index
    set_title "Admin"
  end
  
  def dashboard
    @dashboard = Dashboard.new(params[:min_date] || 3.days.ago.to_date)
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
