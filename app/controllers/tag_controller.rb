class TagController < ApplicationController
	layout 'default'

	before_filter :admin_only, :only => [:rename, :create_alias, :destroy_alias, :create_implication, :destroy_implication]
	before_filter :mod_only, :only => [:mass_edit]

	def cloud
		set_title "Tags"

		@tags = Tag.find(:all, :conditions => "post_count > 0", :order => "post_count DESC", :limit => 100).sort {|a, b| a.name <=> b.name}
	end

	def index
		set_title "Tags"

		case params[:order]
		when "date"
			order = "id DESC"

		when "count"
			order = "post_count DESC"

		else
			order = "name"
		end

		case params[:type]
		when "artist"
			tag_type = Tag::TYPE_ARTIST

		when "character"
			tag_type = Tag::TYPE_CHARACTER

		when "copyright"
			tag_type = Tag::TYPE_COPYRIGHT

		when "general"
			tag_type = Tag::TYPE_GENERAL

		when "ambiguous"
			tag_type = Tag::TYPE_AMBIGUOUS

		else
			tag_type = nil
		end

		if tag_type
			@pages, @tags = paginate :tags, :order => order, :per_page => 50, :conditions => ["tag_type = ?", tag_type]
		else
			@pages, @tags = paginate :tags, :order => order, :per_page => 50
		end

		respond_to do |fmt|
			fmt.html
			fmt.xml {render :xml => @tags.to_xml(:select => params[:select].to_s.split(/,/))}
			fmt.js {render :json => @tags.to_json(:select => params[:select].to_s.split(/,/))}
		end
	end

	def mass_edit
		set_title "Mass Edit Tags"

		if request.post?
			if params[:start].blank?
				respond_to do |fmt|
					fmt.html {flash[:notice] = "You must fill the start tag field"; redirect_to(:action => "mass_edit")}
					fmt.xml {render :xml => {:success => false, :reason => "start tag missing"}, :status => 500}
					fmt.js {render :json => {:success => false, :reason => "start tag missing"}, :status => 500}
				end
				return
			end

			Post.find_by_sql(Post.generate_sql(params[:start])).each do |p|
				start = Tag.to_aliased(Tag.scan_tags(params[:start]))
				result = Tag.to_aliased(Tag.scan_tags(params[:result]))
				tags = (p.cached_tags.scan(/\S+/) - start + result).join(" ")
				p.update_attributes(:updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip, :tags => tags)
			end

			respond_to do |fmt|
				fmt.html {flash[:notice] = "Tags updated"; redirect_to(:action => "mass_edit")}
				fmt.xml {render :xml => {:success => true}.to_xml}
				fmt.js {render :json => {:success => true}.to_json}
			end
		end
	end

	def edit_preview
		@posts = Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC"))
		render :layout => false
	end

	def destroy_alias
		TagAlias.destroy_all(["name = ?", params[:name]])
		Tag.update_cached_tags([params[:name]])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag alias removed"; redirect_to(:action => "aliases")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def create_alias
		TagAlias.create(:name => params[:name], :alias => params[:alias])
		Tag.update_cached_tags([params[:name]])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag alias created"; redirect_to(:action => "aliases")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def destroy_implication
		TagImplication.destroy_all(["parent_id = ? and child_id = ?", params[:parent_id], params[:child_id]])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag implication removed"; redirect_to(:action => "implications")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def create_implication
		TagImplication.create(:parent => params[:parent], :child => params[:child], :updater_user_id => session[:user_id], :updater_ip_addr => request.remote_ip)

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag implication created"; redirect_to(:action => "implications")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def aliases
		set_title "Tag Aliases"
		@aliases = TagAlias.find(:all, :order => "name")
	end

	def implications
		set_title "Tag Implications"
		@implications = TagImplication.find(:all, :order => "(SELECT name FROM tags WHERE id = tag_implications.child_id)")
	end

	def update
		tag = Tag.find_by_name(params[:tag][:name])
		tag.update_attributes(:tag_type => params[:tag][:tag_type])

		respond_to do |fmt|
			fmt.html {flash[:notice] = "Tag updated"; redirect_to(:action => "index")}
			fmt.xml {render :xml => {:success => true}.to_xml}
			fmt.js {render :json => {:success => true}.to_json}
		end
	end

	def edit
		@tag = Tag.new
	end

	def search
		set_title "Search Tags"

		if params[:name] && params[:type]
			name = params[:name]

			case params[:type]
			when "search"
				escaped_name = name.gsub(/\\/, '\\\\').gsub(/%/, '\\%').gsub(/_/, '\\_')
				@tags = Tag.find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\'", escaped_name.gsub(/^/, '%').gsub(/$/, '%').gsub(/ +/, '%')], :order => "name")

			when "artist"
				if name[/^http/]
					escaped_name = File.dirname(name).gsub(/\\/, '\\\\').gsub(/%/, '\\%').gsub(/_/, '\\_') + "%"
					@tags = Tag.find(:all, :conditions => ["id IN (SELECT tag_id FROM posts_tags WHERE post_id IN (SELECT id FROM posts WHERE source LIKE ? ESCAPE '\\\\')) AND tag_type = 1", escaped_name], :order => "name", :limit => 25)
				else
					@tags = Tag.find(:all, :conditions => ["id IN (SELECT tag_id FROM posts_tags WHERE post_id IN (SELECT post_id FROM posts_tags WHERE tag_id = (SELECT id FROM tags WHERE name = ?))) AND tag_type = 1", name], :order => "name", :limit => 25)
				end
			end
		end
	end
end
