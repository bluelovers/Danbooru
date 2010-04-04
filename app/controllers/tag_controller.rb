class TagController < ApplicationController
  layout 'default'
  auto_complete_for :tag, :name
  before_filter :mod_only, :only => [:mass_edit, :edit_preview]
  before_filter :privileged_only, :only => [:update, :edit]

  def cloud
    set_title "Tags"

    @tags = Tag.find(:all, :conditions => "post_count > 0", :order => "post_count DESC", :limit => 100).map {|x| [x.name, x.post_count, x.tag_type]}.sort {|a, b| a[1] <=> b[1]}
  end

  def index
    # TODO: convert to nagato
    set_title "Tags"
    conds = []
    cond_params = []

    if params[:limit] == "0"
      limit = nil
    elsif params[:limit] == nil
      limit = 50
    else
      limit = params[:limit].to_i
    end

    case params[:order]
    when "name"
      order = "name"
      
    when "count"
      order = "post_count desc"
      
    when "date"
      order = "id desc"

    else
      order = "name"
    end
    
    if params[:show_empty_tags].blank?
      conds << "post_count > 0"
    end

    unless params[:name].blank?
      conds << "name LIKE ? ESCAPE E'\\\\'"
      
      if params[:name].include?("*")
        cond_params << params[:name].strip.downcase.to_escaped_for_sql_like
      else      
        cond_params << "%" + params[:name].strip.downcase.to_escaped_for_sql_like + "%"
      end
    end

    unless params[:type].blank?
      conds << "tag_type = ?"
      cond_params << params[:type].to_i
    end

    if params[:after_id]
      conds << "id >= ?"
      cond_params << params[:after_id]
    end

    if params[:id]
      conds << "id = ?"
      cond_params << params[:id]
    end
    
    respond_to do |fmt|
      fmt.html do
        @tags = Tag.paginate :order => order, :per_page => 50, :conditions => [conds.join(" AND "), *cond_params], :page => params[:page]
      end
      fmt.xml do
        order = nil if params[:order] == nil
        conds = conds.join(" AND ")
        if conds == "true" && File.exists?("#{RAILS_ROOT}/public/tags.xml")
          # Special case: instead of rebuilding a list of every tag every time, cache it locally
          # and tell the web server to stream it directly.
          send_file "#{RAILS_ROOT}/public/tags.xml", :x_sendfile => true
        else
          render :xml => Tag.find(:all, :order => order, :limit => limit, :conditions => [conds, *cond_params]).to_xml(:root => "tags")
        end
      end
      fmt.json do
        @tags = Tag.find(:all, :order => order, :limit => limit, :conditions => [conds.join(" AND "), *cond_params])
        render :json => @tags.to_json
      end
    end
  end

  def mass_edit
    set_title "Mass Edit Tags"

    if request.post?
      if params[:start].blank?
        respond_to_error("Start tag missing", {:action => "mass_edit"}, :status => 424)
        return
      end

      if CONFIG["enable_asynchronous_tasks"]
        task = JobTask.create(:task_type => "mass_tag_edit", :status => "pending", :data => {"start_tags" => params[:start], "result_tags" => params[:result], "updater_id" => session[:user_id], "updater_ip_addr" => request.remote_ip})
        respond_to_success("Mass tag edit job created", :controller => "job_task", :action => "index")
      else
        Tag.mass_edit(params[:start], params[:result], @current_user.id, request.remote_ip)
      end
    end
  end

  def edit_preview
    @posts = Post.find_by_sql(Post.generate_sql(params[:tags], :order => "p.id DESC", :limit => 500))
    render :layout => false
  end

  def edit
    @tag = Tag.find_by_name(params[:name]) or Tag.new
  end

  def update
    tag = Tag.find_by_name(params[:tag][:name])
    tag.update_attributes(params[:tag]) if tag
    respond_to_success("Tag updated", :action => "index")
  end

  def related
    if params[:type]
      @tags = Tag.scan_tags(params[:tags])
      @tags = TagAlias.to_aliased(@tags)
      @tags = @tags.inject({}) do |all, x|
        all[x] = Tag.find_related_by_type(x, CONFIG["tag_types"][params[:type]])
        all
      end
    else
      @tags = Tag.scan_tags(params[:tags])
      @patterns, @tags = @tags.partition {|x| x.include?("*")}
      @tags = TagAlias.to_aliased(@tags)
      @tags = @tags.inject({}) do |all, x|
        all[x] = Tag.find_related(x)
        all
      end
      @patterns.each do |x|
        @tags[x] = Tag.find(:all, :conditions => ["name LIKE ? ESCAPE E'\\\\'", x.to_escaped_for_sql_like]).map {|y| [y.name, y.post_count]}
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
      fmt.json {render :json => @tags.to_json}
    end
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
