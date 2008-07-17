class JobTaskController < ApplicationController
  def index
    @job_tasks = JobTask.paginate(:per_page => 25, :order => "id DESC", :page => params[:page])
  end
end
