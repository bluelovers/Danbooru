require File.dirname(__FILE__) + '/../test_helper'

class JobTaskControllerTest < ActionController::TestCase
  def test_all
    job_task = JobTask.create(:task_type => "mass_edit", :status => "pending", :data => {"start" => "a", "result" => "b", "updater_id" => 1, "updater_ip_addr" => "127.0.0.1"})
    
    get :index
    assert_response :success
    
    get :show, {:id => job_task.id}
    assert_response :success
    
    get :retry, {:id => job_task.id}
    assert_response :success
  end
end
