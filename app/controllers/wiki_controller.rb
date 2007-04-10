class WikiController < ApplicationController
	layout 'default'

	if CONFIG["enable_anonymous_wiki_access"]
		unless CONFIG["enable_anonymous_wiki_edits"]
			before_filter :user_only, :only => [:update, :create, :edit, :revert]
		end
	else
		before_filter :user_only
	end

	before_filter :mod_only, :only => [:lock, :unlock, :destroy, :rename]
	verify :method => :post, :only => [:lock, :unlock, :destroy, :update, :create, :revert]

	def destroy
		page = WikiPage.find_page(params[:title])
		WikiPageVersion.destroy_all("wiki_page_id = #{page.id}")
		page.destroy

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Page deleted"; redirect_to(:action => "show", :title => params[:title])}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def lock
		page = WikiPage.find_page(params[:title])
		page.lock!

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Page locked"; redirect_to(:action => "show", :title => params[:title])}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def unlock
		page = WikiPage.find_page(params["title"])
		page.unlock!

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Page unlocked"; redirect_to(:action => "show", :title => params[:title])}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def index
		set_title "Wiki"

		@pages, @wiki_pages = paginate :wiki_pages, :order => "lower(title)", :per_page => 25

		respond_to do |fmt|
			fmt.html
			fmt.xml {render :xml => @wiki_pages.to_xml}
			fmt.js {render :json => @wiki_pages.to_json}
		end
	end

	def preview
		render :inline => "<%= wikilize(params[:body]) %>"
	end

	def create
		page = WikiPage.create(params[:wiki_page].merge(:ip_addr => request.remote_ip, :user_id => session[:user_id]))
		if page.errors.empty?
			respond_to do |fmt|
				location = url_for(:action => "show", :title => page.title)
				fmt.html {flash[:notice] = "New wiki page created"; redirect_to(location)}
				fmt.xml {render :xml => {:success => true, :location => location}.to_xml}
				fmt.js {render :json => {:success => true, :location => location}.to_json}
			end
		else
			respond_to do |fmt|
				error = page.errors.full_messages.join(", ")
				fmt.html {flash[:notice] = "Error: #{error}"; redirect_to(:action => "index")}
				fmt.xml {render :xml => {:success => false, :reason => h(error)}.to_xml, :status => 500}
				fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
			end
		end
	end

	def update
		@page = WikiPage.find_page(params[:title] || params[:wiki_page][:title])

		if @page.is_locked?
			respond_to do |fmt|
				fmt.html {flash[:notice] = "This page is locked and cannot be edited"; redirect_to(:action => "show", :title => params[:title])}
				fmt.xml {render :xml => {:success => false, :reason => "page locked"}.to_xml}
				fmt.js {render :json => {:success => false, :reason => "page locked"}.to_json}
			end
		else
			if @page.update_attributes(params[:wiki_page].merge(:ip_addr => request.remote_ip, :user_id => session[:user_id]))
				respond_to do |fmt|
					fmt.html {flash[:notice] = "Wiki page updated"; redirect_to(:action => "show", :title => @page.title)}
					fmt.xml {render :xml => {:success => true}.to_xml}
					fmt.js {render :json => {:success => true}.to_json}
				end
			else
				respond_to do |fmt|
					error = page.errors.full_messages.join(", ")
					fmt.html {flash[:notice] = "Error: #{error}"; redirect_to(:action => "index")}
					fmt.xml {render :xml => {:success => false, :reason => h(error)}.to_xml, :status => 500}
					fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
				end
			end
		end
	end

	def show
		@page = WikiPage.find_page(params[:title], params[:version])
		set_title params[:title].tr("_", " ")
	end

	def edit
		@wiki_page = WikiPage.find_page(params[:title], params[:version]) || WikiPage.new(:title => params[:title])

		if @wiki_page.new_record? && (Tag.find_by_name(@wiki_page.title).tag_type == Tag.types[:artist] rescue false)
			@wiki_page.body =<<-EOL
Artist.

Circle name: 
Japanese name: 
Site name: 

h4. See also

* "Home page":
			EOL
		end
		set_title @wiki_page.pretty_title + " (Editing)"
	end

	def revert
		@page = WikiPage.find_page(params[:title])

		if @page.is_locked?
			respond_to do |fmt|
				fmt.html {flash[:notice] = "This page is locked and cannot be edited"; redirect_to(:action => "show", :title => params[:title])}
				fmt.xml {render :xml => {:success => false, :reason => "page locked"}.to_xml, :status => 409}
				fmt.js {render :json => {:success => false, :reason => "page locked"}.to_json, :status => 409}
			end
		else
			@page.ip_addr = request.remote_ip

			if @page.revert_to!(params[:version])
				respond_to do |fmt|
					fmt.html {flash[:notice] = "Wiki page was reverted"; redirect_to(:action => "show", :title => @page.title)}
					fmt.xml {render :xml => {:success => true}.to_xml}
					fmt.js {render :json => {:success => true}.to_json}
				end
			else
				respond_to do |fmt|
					error = @page.errors.full_messages.join(", ")
					fmt.html {flash[:notice] = "Error: #{error}"; redirect_to(:action => "index")}
					fmt.xml {render :xml => {:success => false, :reason => h(error)}.to_xml, :status => 500}
					fmt.js {render :json => {:success => false, :reason => escape_javascript(error)}.to_json, :status => 500}
				end
			end
		end
	end

	def history
		set_title "Wiki History"

		if params["title"]
			@wiki_pages = WikiPageVersion.find(:all, :conditions => ["title = ?", params["title"]], :order => "updated_at DESC")
		else
			@pages, @wiki_pages = paginate :wiki_page_versions, :order => "updated_at DESC", :per_page => 25
		end
	end

	def diff
		set_title "Wiki Diff"

		if params[:redirect]
			redirect_to :action => "diff", :title => params[:title], :from => params[:from], :to => params[:to]
			return
		end

		@oldpage = WikiPage.find_page(params[:title], params[:from])
		@difference = @oldpage.diff(params[:to])
	end

	def rename
		@wiki_page = WikiPage.find_page(params[:title])

		if request.post?
			@wiki_page.rename!(params[:wiki_page][:title])

			respond_to do |fmt|
				fmt.html {flash[:notice] = "Wiki page renamed"; redirect_to(:action => "show", :title => params[:wiki_page][:title])}
				fmt.xml {render :xml => {:success => true}.to_xml}
				fmt.js {render :json => {:success => true}.to_json}
			end
		end
	end
end
