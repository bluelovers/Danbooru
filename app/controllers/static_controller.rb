class StaticController < ApplicationController
  layout "bare"
  
  def overloaded
    render :layout => "default"
  end
  
  def state_of_danbooru
    render :layout => "default"
  end
  
  def clear_cache
    Cache.delete(params[:key])
  end
end
