class StaticController < ApplicationController
	layout "bare"

	def redirect
		render :layout => false
	end

	def notfound
		redirect_to '/404.html'
	end
end
