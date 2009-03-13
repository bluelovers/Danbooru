class PixivController < ApplicationController
	layout "default"
	
	def index
		if params[:url]
			page_type, @results = PixivProxy.get(params[:url])
			
			case page_type
			when "single"
				render :action => "single"
				
			when "listing"
				render :action => "listing"
				
			when "profile"
				render :action => "profile"
			end
		end
	end
end
