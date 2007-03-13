class ArtistController < ApplicationController
	layout "default"

	def edit
		@artist = Artist.find(params["id"])

		if request.post?
			@artist.update_attributes(params["artist"])
			redirect_to :action => "list"
		end
	end

	def add
		if request.post?
			Artist.create(params["artist"])
			redirect_to :action => "list"
		end
	end

	def list
		@artists = Artist.find(:all, :order => "personal_name, handle_name, circle_name")
	end

	def find
	end

	def view
	end
end
