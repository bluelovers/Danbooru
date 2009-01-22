class ReportController < ApplicationController
  layout 'default'
  before_filter :set_dates
  
  def tag_updates
    @users = Report.tag_updates(@start_date, @end_date)
    @report_title = "Tag Updates"
    @change_params = lambda {|user_id| {:controller => "post_tag_history", :action => "index", :user_id => user_id}}
    render :action => "common"
  end
  
  def note_updates
    @users = Report.note_updates(@start_date, @end_date)
    @report_title = "Note Updates"
    @change_params = lambda {|user_id| {:controller => "note", :action => "history", :user_id => user_id}}
    render :action => "common"
  end
  
  def wiki_updates
    @users = Report.wiki_updates(@start_date, @end_date)
    @report_title = "Wiki Updates"
    @change_params = lambda {|user_id| {:controller => "wiki", :action => "recent_changes", :user_id => user_id}}
    render :action => "common"
  end
  
  def post_uploads
    @users = Report.wiki_updates(@start_date, @end_date)
    @report_title = "Post Uploads"
    @change_params = lambda {|user_id| {:controller => "post", :action => "index", :tags => "user:#{User.find_name(user_id)}"}}
    render :action => "common"
  end
  
private
  def set_dates
    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
    else
      @start_date = 3.days.ago.to_date
    end
    
    if params[:end_date]
      @end_date = Date.parse(params[:end_date])
    else
      @end_date = Date.today
    end
  end
end
