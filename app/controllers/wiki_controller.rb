class WikiController < ApplicationController
	layout 'default'
	before_filter :user_only, :only => [:save, :edit, :revert] unless CONFIG["allow_anonymous_wiki_edits"]
	before_filter :mod_only, :only => [:lock, :unlock, :delete, :rename]

	def delete
		if request.post?
			page = WikiPage.find_page(params["title"])
			WikiPageVersion.destroy_all("wiki_page_id = #{page.id}")
			page.destroy
			flash[:notice] = "Page deleted"
			redirect_to :action => "view", :title => params["title"]
		end
	end

	def lock
		page = WikiPage.find_page(params["title"])
		page.lock!
		flash[:notice] = "Page locked"
		redirect_to :action => "view", :title => params["title"]
	end

	def unlock
		page = WikiPage.find_page(params["title"])
		page.unlock!
		flash[:notice] = "Page unlocked"
		redirect_to :action => "view", :title => params["title"]
	end

	def list
		set_title "Wiki Pages"

		@pages, @wiki_pages = paginate :wiki_pages, :order => "lower(title)", :per_page => 25
	end

	def preview
		render :inline => "<%= wikilize(@params['body']) %>"
	end

	def save
		if request.post?
			if params["create"]
				@page = WikiPage.new(:title => params["title"])
			else
				@page = WikiPage.find_page(params["title"])
			end

			if @page.is_locked?
				flash[:notice] = "This page is locked and cannot be edited"
				redirect_to :action => "view", :title => params["title"]
			else
				@page.body = params["wiki-text"]
				@page.ip_addr = request.remote_ip
				@page.user_id = current_user().id rescue nil

				if @page.save
					redirect_to :action => "view", :title => @page.title
				else
					render_error(@page)
				end
			end
		end
	end

	def view
		@page = WikiPage.find_page(params["title"], params["version"])
		set_title params["title"].tr("_", " ")
	end

	def edit
		@page = WikiPage.find_page(params["title"], params["version"]) || WikiPage.new(:title => params["title"], :user_id => (current_user().id rescue nil), :ip_addr => request.remote_ip)
		set_title @page.pretty_title + " (Editing)"
	end

	def revert
		set_title "Revert Wiki"

		if request.post?
			@page = WikiPage.find_page(params["title"])

			if @page.is_locked?
				flash[:notice] = "This page is locked and cannot be edited"
				redirect_to :action => "view", :title => params["title"]
				return
			end

			@page.ip_addr = request.remote_ip

			if @page.revert_to!(params["version"])
				redirect_to :action => "view", :title => @page.title
			else
				render_error(@page)
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

		if params["redirect"]
			redirect_to :controller => "wiki", :action => "diff", :title => @params["title"], :from => params["from"], :to => params["to"]
			return
		end

		@oldpage = WikiPage.find_page(params["title"], params["from"])
		@difference = @oldpage.diff(params["to"])
	end

	def rename
		set_title "Rename Wiki"

		@page = WikiPage.find_page(params["title"])

		if request.post?
			@page.rename!(params["new_title"])
			flash[:notice] = "Wiki renamed"
			redirect_to :action => "view", :title => params["new_title"]
		end
	end
end
