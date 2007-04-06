class TagAliasController < ApplicationController
	before_filter :admin_only, :only => [:update]
	verify :method => :post, :only => [:create, :update]

	def create
		TagAlias.create(params[:tag_alias])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag alias created"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def index
		set_title "Tag Aliases"
		@pages, @aliases = paginate :tag_aliases, :order => "is_pending, name", :per_page => 50
	end

	def add
		@tag_alias = TagAlias.new
	end

	def update
		ids = params[:aliases].keys

		case params[:commit]
		when "Delete"
			ids.each {|x| TagAlias.destroy(x)}
			
			respond_to do |fmt|
				fmt.html {flash[:notice] = "Tag aliases deleted"; redirect_to(:action => "index")}
				fmt.xml {render :xml => {:success => true}.to_xml}
				fmt.js {render :json => {:success => true}.to_json}
			end

		when "Approve"
			ids.each {|x| TagAlias.find(x).approve!}

			respond_to do |fmt|
				fmt.html {flash[:notice] = "Tag aliases approved"; redirect_to(:action => "index")}
				fmt.xml {render :xml => {:success => true}.to_xml}
				fmt.js {render :json => {:success => true}.to_json}
			end
		end
	end
end
