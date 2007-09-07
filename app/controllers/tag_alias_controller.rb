class TagAliasController < ApplicationController
	layout "default"
	before_filter :admin_only, :only => [:update]
	before_filter :member_only, :only => [:create]
	verify :method => :post, :only => [:create, :update]

	def create
		TagAlias.create(params[:tag_alias].merge(:is_pending => true))

		flash[:notice] = "Tag alias created"
		redirect_to :action => "index"
	end

	def index
		set_title "Tag Aliases"
		@pages, @aliases = paginate :tag_aliases, :order => "is_pending DESC, name", :per_page => 50

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @aliases.to_xml}
      fmt.js {render :json => @aliases.to_json}
    end
	end

	def update
		ids = params[:aliases].keys

		case params[:commit]
		when "Delete"
			ids.each {|x| TagAlias.destroy(x)}
			
			flash[:notice] = "Tag aliases deleted"
			redirect_to :action => "index"

		when "Approve"
			ids.each {|x| TagAlias.find(x).approve!}

			flash[:notice] = "Tag aliases approved"
			redirect_to :action => "index"
		end
	end
end
