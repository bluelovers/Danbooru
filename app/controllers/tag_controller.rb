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
      @pages, @tags = paginate :tags, :order => order, :per_page => params[:limit] || 50, :conditions => ["tag_type = ? AND id >= ?", tag_type, params[:after_id] || 0]
    else
      @pages, @tags = paginate :tags, :order => order, :per_page => 50, :conditions => ["id >= ?", params[:after_id] || 0]]
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
      @tags = Tag.scan_tags(params[:tags])
      @tags = TagAlias.to_aliased(@tags)
      @tags = @tags.map {|x| Tag.calculate_related_by_type(x, Tag.types[params[:type]])}
      @tags = @tags.inject([]) {|all, x| all += x.map {|y| [y["name"].to_escaped_js, y["post_count"]]}}
    else
      @tags = params[:tags].to_s.scan(/\S+/)
      @patterns, @tags = @tags.partition {|x| x.include?("*")}
      @tags = TagAlias.to_aliased(@tags)
      @tags = @tags.inject([]) {|all, x| all += Tag.find_related(x)}
      @tags = @tags.map {|y| [y[0].to_escaped_js, y[1]]}
      @patterns = @patterns.map {|x| x.to_escaped_for_sql_like}
      @patterns = @patterns.inject([]) {|all, x| all += Tag.find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\'", x])}
      @patterns = @patterns.map {|x| [x.name.to_escaped_js, x.post_count]}
      @tags += @patterns
    end

    respond_to do |fmt|
      fmt.js {render :json => @tags.to_json}
    end
  end

  def search
    set_title "Search Tags"

    sql_conds = []
    sql_params = []

    if !params[:tag_name].blank?
      sql_conds << "name LIKE ? ESCAPE '\\\\'"
      sql_params << "%" + params[:tag_name].gsub(/\\/, '\\\\').gsub(/%/, '\\%').gsub(/_/, '\\_') + "%"
    end

    if !params[:tag_type].blank?
      sql_conds << "tag_type = ?"
      sql_params << params[:tag_type].to_i
    end

    if params[:tag_ambiguous] == "1"
      sql_conds << "is_ambiguous = TRUE"
    end

    if sql_conds.empty?
      sql_conds << "FALSE"
    end

    if params[:tag_order] == "name"
      order = "name"
    elsif params[:tag_order] = "date"
      order = "id desc"
    else
      order = "name"
    end

    @tags = Tag.find(:all, :conditions => [sql_conds.join(" AND "), *sql_params], :order => order)
  end

  def romanize
    romanji = ROMANIZER.romanize(params[:tags])

    render :text => romanji, :layout => false
  end
end
