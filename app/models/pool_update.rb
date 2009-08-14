class PoolUpdate < ActiveRecord::Base
  belongs_to :pool
  
  def updater_name
    User.find_name(user_id).tr("_", " ")
  end
  
  def sanitized_ip_addr
    ip_addr.to_s.sub(/\d+\.\d+$/, "x.x")
  end
  
  def post_count
    post_ids.split(" ").size / 2
  end
  
  def post_ids_only
    post_ids.scan(/(\d+) \d+/).flatten
  end
end
