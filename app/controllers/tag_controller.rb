class TagController < ApplicationController
	layout 'default'

	before_filter :admin_only, :only => [:rename]
	before_filter :mod_only, :only => [:mass_edit]

	def cloud
		set_title "Tags"

		@tags = Tag.find(:all, :conditions => "post_count > 0", :order => "post_count DESC", :limit => 100).sort {|a, b| a.name <=> b.name}
	end

	def index
		set_title "Tags"

		if params[:letter]
			sql = "SELECT count(*) FROM tags WHERE substring(name FROM 1 FOR 1) < ?"
			cond_params = [params[:letter]]

			if params[:type]
				sql << " AND tag_type = ?"
				cond_params << Tag.types[params[:type]]
			end

			page = (Tag.count_by_sql([sql, *cond_params]) / 50) + 1
			redirect_to :action => "index", :order => params[:order], :type => params[:type], :page => page, :letter => nil
			return
		end

		case params[:order]
		when "date"
			order = "id DESC"

		when "count"
			order = "post_count DESC"

		else
			order = "name"
		end

		tag_type = Tag.types[params[:type]]

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
				start = TagAlias.to_aliased(Tag.scan_tags(params[:start]))
				result = TagAlias.to_aliased(Tag.scan_tags(params[:result]))
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

	def update
		tag = Tag.find_or_create_by_name(params[:tag][:name])
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

	def related
		if params[:type]
			@tags = Tag.calculate_related_by_type(params[:name], Tag.types[params[:type]]).map {|x| [x["name"].to_escaped_js, x["post_count"]]}
		else
			@tags = Tag.find_related(params[:name]).map {|x| [x[0].to_escaped_js, x[1]]}
		end

		respond_to do |fmt|
			fmt.js {render :json => @tags.to_json}
		end
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
					@tags = Tag.find(:all, :conditions => ["id IN (SELECT tag_id FROM posts_tags WHERE post_id IN (SELECT id FROM posts WHERE source LIKE ? ESCAPE '\\\\')) AND tag_type = ?", escaped_name, Tag.types[:artist]], :order => "name")
				else
					@tags = Tag.calculate_related_by_type(name, Tag.types[:artist])
				end
			end
		end
	end
end
