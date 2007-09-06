class TagController < ApplicationController
  layout 'default'
  auto_complete_for :tag, :name
  before_filter :mod_only, :only => [:mass_edit]

  def cloud
    set_title "Tags"

    @tags = Tag.find(:all, :conditions => "post_count > 0", :order => "post_count DESC", :limit => 100).sort {|a, b| a.name <=> b.name}
  end

  def index
    set_title "Tags"

    if params[:limit] == "0"
      limit = nil
    elsif params[:limit] == nil
      limit = 50
    else
      limit = params[:limit].to_i
    end

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

    sql_conds = []
    sql_params = []

    if Tag.types[params[:type]]
      sql_conds << "tag_type = ?"
      sql_params << Tag.types[params[:type]]
    end

    if params[:after_id]
      sql_conds << "id >= ?"
      sql_params << params[:after_id]
    end

    if params[:id]
      sql_conds << "id = ?"
      sql_params << params[:id]
    end

    if params[:name]
      sql_conds << "name = ?"
      sql_params << params[:name]
    end

    if params[:name_pattern]
      sql_conds << "name ILIKE ? ESCAPE '\\\\'"
      sql_params << ("%" + params[:name_pattern].to_escaped_for_sql_like + "%")
    end

    sql_conds << "TRUE" # for the empty case

    @pages, @tags = paginate :tags, :order => order, :per_page => limit, :conditions => [sql_conds.join(" AND "), *sql_params]

    respond_to do |fmt|
      fmt.html
      fmt.xml {render :xml => @tags.to_xml}
      fmt.js {render :json => @tags.to_json}
    end
  end

  def mass_edit
    set_title "Mass Edit Tags"

    if request.post?
      if params[:start].blank?
        respond_to do |fmt|
          fmt.html {flash[:notice] = "You must fill the start tag field"; redirect_to(:action => "mass_edit")}
          fmt.xml {render :xml => {:success => false, :reason => "start tag missing"}.to_xml(:root => "response"), :status => 500}
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
        fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
        fmt.js {render :json => {:success => true}.to_json}
      end
    end
  end

  def edit_preview
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC", :limit => 500))
    render :layout => false
  end

  def update
    tag = Tag.find_by_name(params[:tag][:name])
    tag.update_attributes(params[:tag]) if tag

    respond_to do |fmt|
      fmt.html {flash[:notice] = "Tag updated"; redirect_to(:action => "index")}
      fmt.xml {render :xml => {:success => true}.to_xml(:root => "response")}
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
      @tags = @tags.inject({}) do |all, x| 
        all[x] = Tag.calculate_related_by_type(x, Tag.types[params[:type]]).map {|y| [y["name"], y["post_count"]]}
        all
      end
    else
      @tags = params[:tags].to_s.scan(/\S+/)
      @patterns, @tags = @tags.partition {|x| x.include?("*")}
      @tags = TagAlias.to_aliased(@tags)
      @tags = @tags.inject({}) do |all, x|
        all[x] = Tag.find_related(x).map {|y| puts y; [y[0], y[1]]}
        all
      end
      @patterns.each do |x|
        @tags[x] = Tag.find(:all, :conditions => ["name LIKE ? ESCAPE '\\\\'", x.to_escaped_for_sql_like]).map {|y| [y.name, y.post_count]}
      end
    end

    respond_to do |fmt|
      fmt.xml do
        # We basically have to do this by hand.
        builder = Builder::XmlMarkup.new(:indent => 2)
        builder.instruct!
        xml = builder.tag!("tags") do
          @tags.each do |parent, related|
            builder.tag!("tag", :name => parent) do
              related.each do |tag, count|
                builder.tag!("tag", :name => tag, :count => count)
              end
            end
          end
        end
        
        render :xml => xml
      end
      fmt.js {render :json => @tags.to_json}
    end
  end

  def romanize
    romanji = ROMANIZER.romanize(params[:tags])

    render :text => romanji, :layout => false
  end

  def popular_by_day
    if params["year"] and params["month"] and params["day"]
      @day = Time.gm(params["year"].to_i, params["month"], params["day"])
    else
      @day = Time.new.getgm.at_beginning_of_day
    end

    @tags = Tag.count_by_period(@day.beginning_of_day, @day.tomorrow.beginning_of_day)
  end

  def popular_by_week
    if params["year"] and params["month"] and params["day"]
      @day = Time.gm(params["year"].to_i, params["month"], params["day"]).beginning_of_week
    else
      @day = Time.new.getgm.at_beginning_of_day.beginning_of_week
    end

    @tags = Tag.count_by_period(@day, @day.next_week)
  end

  def popular_by_month
    if params["year"] and params["month"]
      @day = Time.gm(params["year"].to_i, params["month"], params["day"]).beginning_of_month
    else
      @day = Time.new.getgm.at_beginning_of_day.beginning_of_month
    end

    @tags = Tag.count_by_period(@day, @day.next_month)
  end
end
