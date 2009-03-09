class AdvertisementController < ApplicationController
	before_filter :admin_only, :only => [:create, :update, :new, :edit]
  layout "default"

	def redirect_ad
		ad = Advertisement.find(params[:id])
    ad.hit!(request.remote_ip)
		redirect_to ad.referral_url
	end
	
	def index
		@ads = Advertisement.find(:all, :order => "id")

    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
    else
      @start_date = 1.month.ago.to_date
    end

    if params[:end_date]
      @end_date = Date.parse(params[:end_date])
    else
      @end_date = Date.today
    end
	end

  def new
    @ad = Advertisement.new
  end

  def create
    @ad = Advertisement.create(params[:ad])
    flash[:notice] = "Advertisement created"
    redirect_to :action => "index"
  end

  def edit
    @ad = Advertisement.find(params[:id])
  end

  def update
    @ad = Advertisement.find(params[:id])
    @ad.update_attributes(params[:ad])
    flash[:notice] = "Advertisement updated"
    redirect_to :action => :index
  end
end
