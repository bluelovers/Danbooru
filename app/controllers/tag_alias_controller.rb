class TagAliasController < ApplicationController
	before_filter :admin_only, :only => [:approve, :destroy]
	verify :method => :post, :only => [:create, :destroy, :approve]

	def create
		TagAlias.create(params[:tag_alias])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag alias created"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def destroy
		ta = TagAlias.find(params[:id])
		ta.destroy
		Tag.update_cached_tags(ta.name)

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag alias removed"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def index
		set_title "Tag Aliases"
		@pages, @aliases = paginate :tag_aliases, :order => "is_pending, name", :per_page => 50
	end

	def approve
		tag = TagAlias.find(params[:id])
		tag.approve!

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag alias approved"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success = true}.to_json}
		end
	end

	def add
		@tag_alias = TagAlias.new
	end
end
