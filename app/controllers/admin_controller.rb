class AdminController < ApplicationController
  layout "default"
  before_filter :admin_only

  def index
    set_title "Admin"
  end

  def edit_account
    set_title "Edit Account"

    if request.post?
      @user = User.find_by_name(params["user"]["name"])
      @user.level = params["user"]["level"]

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

  def settings
    if request.post?
      CONFIG.each_key do |x|
        case CONFIG[x]
        when Integer
          CONFIG[x] = params[x].to_i

        when TrueClass, FalseClass
          CONFIG[x] = params[x] == "true" ? true : false

        when Symbol
          CONFIG[x] = params[x].to_sym

        else
          CONFIG[x] = params[x]
        end
      end

      redirect_to :action => "settings"
    end
  end
end
