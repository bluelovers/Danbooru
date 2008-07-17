require File.dirname(__FILE__) + '/../test_helper'

class JobTaskTest < ActiveSupport::TestCase
  def test_all
    assert(!File.exists?("#{RAILS_ROOT}/log/job_task_processor.rb.pid"))
    `ruby #{RAILS_ROOT}/app/daemons/job_task_processor_ctl.rb start`
    sleep 2
    
    begin
      assert(File.exists?("#{RAILS_ROOT}/log/job_task_processor.rb.pid"))
      ta = TagAlias.create(:name => "a", :alias => "b", :creator_id => 1)
      JobTask.create(:task_type => "approve_tag_alias", :status => "pending", :data => {"id" => ta.id})
      sleep 2
      ta.reload
      assert(!ta.is_pending?)
    ensure
      `ruby #{RAILS_ROOT}/app/daemons/job_task_processor_ctl.rb stop`
      sleep 2
    end
    
    assert(!File.exists?("#{RAILS_ROOT}/log/job_task_processor.rb.pid"))
  end
end
