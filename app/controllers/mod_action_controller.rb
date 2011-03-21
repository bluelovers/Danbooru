class ModActionController < ApplicationController
  layout "default"
  
  def index
    @mod_actions = ModAction.paginate(:page => params[:page], :order => "id desc")
  end
end
