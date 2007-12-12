class AdminController < ApplicationController
  layout "default"
  before_filter :admin_only

  def index
    set_title "Admin"
  end

  def edit_account
    set_title "Edit Account"

    if request.post?
      @user = User.find_by_name(params[:user][:name])
      @user.level = params[:user][:level]

      if @user.save
        redirect_to :action => "edit_account"
      else
        render_error(@user)
      end
    end
  end

  def reset_password
    if request.post?
      @user = User.find_by_name(params[:user][:name])
      
      if @user
        if @user.email.blank?
          flash[:notice] = "User never supplied an email address"
          redirect_to :action => "index"
        else
          new_password = @user.reset_password
          UserMailer.deliver_new_password(@user, new_password)

          flash[:notice] = "Password reset"
          redirect_to :action => "index"
        end
      else
        flash[:notice] = "That account does not exist"
        redirect_to :action => "reset_password"
      end
    else
      @user = User.new
    end
  end

  def cache_stats
    if params[:key]
      if params[:commit] == "Update"
        if params[:value] =~ /^s:/
          Cache.put(params[:key], params[:value][2..-1])
        else
          Cache.put(params[:key], params[:value].to_i)
        end
        
        flash[:notice] = "Cache updated"
      end
      
      @value = Cache.get(params[:key])
    end
  end
end
