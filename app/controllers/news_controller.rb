class NewsController < ApplicationController
  layout 'default'
  before_filter :admin_only, :only => [:update, :create, :destroy, :edit, :new]
  verify :method => :post, :only => [:update, :create, :destroy]


  def show
    @news_update = NewsUpdate.find(params[:id])
  end

  def index
    @pages, @news_updates = paginate :news_updates, :order => "updated_at desc", :per_page => 15
  end

  def update
    flash[:notice] = "News update updated"
    @news_update = NewsUpdate.find(params[:id])
    @news_update.update_attributes(params[:news_update])
    redirect_to :action => "show", :id => @news_update.id
  end

  def create
    flash[:notice] = "News update created"
    @news_update = NewsUpdate.create(params[:news_update].merge(:user_id => @current_user.id))
    redirect_to :action => "show", :id => @news_update.id
  end

  def destroy
    NewsUpdate.destroy(params[:id])
    redirect_to :action => "index"
  end

  def edit
    @news_update = NewsUpdate.find(params[:id])
  end

  def new
    @news_update = NewsUpdate.new
  end
end
