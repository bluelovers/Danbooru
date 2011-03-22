class ModActionController < ApplicationController
  layout "default"
  
  def index
    @mod_actions = ModAction.paginate(:page => params[:page], :order => "id desc", :conditions => ["created_at >= ?", 14.days.ago])
  end
end
