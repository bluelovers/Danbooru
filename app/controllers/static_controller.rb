class StaticController < ApplicationController
	layout "bare"

	def redirect
		render :layout => false
	end
end
