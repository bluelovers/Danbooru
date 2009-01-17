class JobTask < ActiveRecord::Base
  TASK_TYPES = %w(mass_tag_edit approve_tag_alias approve_tag_implication calculate_favorite_tags)
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
    if repeat_count > 0
      count = repeat_count - 1
    else
      count = repeat_count
    end
    
    begin
      execute_sql("SET statement_timeout = 0")
      update_attributes(:status => "processing")
      __send__("execute_#{task_type}")
      
      if count == 0
        update_attributes(:status => "finished")
      else
        update_attributes(:status => "pending", :repeat_count => count)
      end
    rescue SystemExit => x
      update_attributes(:status => "pending")
    rescue Exception => x
      update_attributes(:status => "error", :status_message => "#{x.class}: #{x}")
    end
  end
  
  def execute_mass_tag_edit
    start_tags = data["start_tags"]
    result_tags = data["result_tags"]
    updater_id = data["updater_id"]
    updater_ip_addr = data["updater_ip_addr"]
    Tag.mass_edit(start_tags, result_tags, updater_id, updater_ip_addr)
  end
  
  def execute_approve_tag_alias
    ta = TagAlias.find(data["id"])
    updater_id = data["updater_id"]
    updater_ip_addr = data["updater_ip_addr"]
    ta.approve(updater_id, updater_ip_addr)
  end
  
  def execute_approve_tag_implication
    ti = TagImplication.find(data["id"])
    updater_id = data["updater_id"]
    updater_ip_addr = data["updater_ip_addr"]
    ti.approve(updater_id, updater_ip_addr)
  end
  
  def execute_calculate_favorite_tags
    return if Cache.get("delay-favtags-calc")

    last_processed_post_id = data["last_processed_post_id"].to_i
    
    if last_processed_post_id == 0
      last_processed_post_id = Post.maximum("id").to_i
    end
    
    Cache.put("delay-favtags-calc", "1", 5.minutes)
    new_id = FavoriteTag.process_all(last_processed_post_id)
    update_attributes(:data => {"last_processed_post_id" => new_id})
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
      "start:#{ti.predicate.name} result:#{ti.consequent.name}"
      
    when "calculate_favorite_tags"
      "post_id:#{data['last_processed_post_id']}"
    end
  end
  
  def self.execute_once
    find(:all, :conditions => ["status = ?", "pending"], :order => "id desc").each do |task|
      task.execute!
      sleep 1
    end
  end
  
  def self.execute_all
    while true
      execute_once
      sleep 60
    end
  end  
end
