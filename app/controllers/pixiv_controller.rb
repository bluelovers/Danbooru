class PixivController < ApplicationController
	def upload_info
		@results = PixivProxy.get(params[:url])
		@artist = Artist.find_by_name(@results[:artist].downcase) if @results[:artist]
	end
	
	def always_fetch
	  session[:always_fetch_pixiv] = true
	  render :nothing => true
  end
end
