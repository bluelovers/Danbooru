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

  def reset_cache
    $cache_version += 1
    redirect_to :action => "index"
  end
end
