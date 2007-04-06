class TagImplicationController < ApplicationController
	before_filter :admin_only, :only => [:approve, :destroy]
	verify :method => :post, :only => [:create, :destroy, :approve]

	def create
		TagImplication.create(params[:tag_implication])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag implication created (approval pending)"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def destroy
		ti = TagImplication.find(params[:id])
		ti.destroy

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag implication removed"; redirect_to(:action => "implications")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def approve
		tag = TagImplication.find(params[:id])
		tag.approve!

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag implication approved"; redirect_to(:action => "implications")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def index
		set_title "Tag Implications"
		@pages, @implications = paginate :tag_implications, :order => "is_pending, (SELECT name FROM tags WHERE id = tag_implications.child_id)", :per_page => 50
	end

	def add
		@tag_implication = TagImplication.new
	end
end
