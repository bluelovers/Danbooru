class StaticController < ApplicationController
  layout "bare"
  
  def overloaded
    render :layout => "default"
  end
end
