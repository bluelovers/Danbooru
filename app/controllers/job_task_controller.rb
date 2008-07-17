class JobTaskController < ApplicationController
  layout "default"
  
  def index
    @job_tasks = JobTask.paginate(:per_page => 25, :order => "id DESC", :page => params[:page])
  end
end
