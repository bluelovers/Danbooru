class ArtistController < ApplicationController
	layout "default"

# Parameters
# - id: the ID number of the artist to update
# - artist[personal_name]: the artist's personal name (in romanji)
# - artist[handle_name]: the artist's handle or nickname
# - artist[circle_name]: the artist's circle name
# - artist[japanese_name]: the artist's japanese name (in kanji or kana)
# - artist[site_name]: the artist's site's name
# - artist[site_url]: base URL of the artist's home page
# - artist[image_url]: base URL of the site storing the artist's images
	def update
		artist = Artist.find(params[:id])
		artist.update_attributes(params[:artist])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Artist entry updated"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:sucess => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

# Parameters
# - artist[personal_name]: the artist's personal name (in romanji)
# - artist[handle_name]: the artist's handle or nickname
# - artist[circle_name]: the artist's circle name
# - artist[japanese_name]: the artist's japanese name (in kanji or kana)
# - artist[site_name]: the artist's site's name
# - artist[site_url]: base URL of the artist's home page
# - artist[image_url]: base URL of the site storing the artist's images
	def create
		artist = Artist.create(params[:artist])
		respond_to do |fmt|
			fmt.html {flash[:notice] = "Artist created"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json > {:success => true}.to_json}
		end
	end

	def edit
		@artist = Artist.find(params["id"])
	end

	def add
		@artist = Artist.new
	end

# Parameters
# - name: the artist's name. Danbooru will automatically search in the following order: personal name, handle name, circle name, japanese name. If you prefix with "site:", Danbooru will search against the URL database, both site URLs and image URLs. Danbooru will automatically progressively shorten the supplied URL until either a match is found or the string is too short (so you can supply direct links to images and Danbooru will find a match).
	def index
		if params[:name]
			name = params[:name]

			if name =~ /^site:/
				name = name[5..-1]
				@artists = []

				while @artists.empty? && name.size > 7
					escaped_name = name.gsub(/'/, "''").gsub(/\\/, '\\\\')
					@pages, @artists = paginate :artists, :conditions => "site_url LIKE '#{escaped_name}%' ESCAPE '\\\\' OR image_url LIKE '#{escaped_name}%' ESCAPE '\\\\'", :order => "personal_name, handle_name, circle_name, japanese_name", :per_page => 25
					name = File.dirname(name)
				end
			else
				name = name.gsub(/'/, "''").gsub(/\\/, '\\\\')
				@pages, @artists = paginate :artists, :conditions => "personal_name LIKE '%#{name}%' ESCAPE '\\\\' OR handle_name LIKE '%#{name}%' ESCAPE '\\\\' OR circle_name LIKE '%#{name}%' ESCAPE '\\\\' OR japanese_name LIKE '%#{name}%' ESCAPE '\\\\'", :order => "personal_name, handle_name, circle_name, japanese_name", :per_page => 25
			end
		else
			@pages, @artists = paginate :artists, :order => "personal_name, handle_name, circle_name, japanese_name", :per_page => 25
		end

		respond_to do |fmt|
			fmt.html
			fmt.xml {render :xml => @artists.to_xml}
			fmt.js {render :json => @artists.to_json}
		end
	end

	def show
	end
end
