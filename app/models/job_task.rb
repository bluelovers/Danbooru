class JobTask < ActiveRecord::Base
  TASK_TYPES = %w(mass_tag_edit approve_tag_alias approve_tag_implication)
  STATUSES = %w(pending processing finished error)
  
  validates_inclusion_of :task_type, :in => TASK_TYPES
  validates_inclusion_of :status, :in => STATUSES
  
  def data
    JSON.parse(data_as_json)
  end
  
  def data=(hoge)
    self.data_as_json = hoge.to_json
  end
  
  def execute!
    begin
      update_attribute(:status, "processing")
      __send__("execute_#{task_type}")
      update_attribute(:status, "finished")
    rescue Exception => x
      update_attributes(:status => "error", :status_message => "#{x.class}: #{x}")
    end
  end
  
  def execute_mass_tag_edit
    start_tags = data["start_tags"]
    result_tags = data["results_tags"]
    updater_id = data["updater_id"]
    updater_ip_addr = data["updater_ip_addr"]
    Tag.mass_edit(start_tags, result_tags, updater_id, updater_ip_addr)
  end
  
  def execute_approve_tag_alias
    ta = TagAlias.find(data["id"])
    ta.approve
  end
  
  def execute_approve_tag_implication
    ti = TagImplication.find(data["id"])
    ti.approve
  end
  
  def pretty_data
    case task_type
    when "mass_tag_edit"
      start = data["start_tags"]
      result = data["result_tags"]
      user = User.find_name(data["updater_id"])
      
      "start:#{start} result:#{result} user:#{user}"
      
    when "approve_tag_alias"
      ta = TagAlias.find(data["id"])
      "start:#{ta.name} result:#{ta.alias_name}"
      
    when "approve_tag_implication"
      ti = TagImplication.find(data["id"])
      "start:#{ti.predicate_name} result:#{ti.consequent_name}"
    end
  end
  
  def self.execute_all
    while true
      task = find(:first, :conditions => ["status = ?", "pending"], :order => "id")
      task.execute! if task
      sleep 1
    end
  end  
end
