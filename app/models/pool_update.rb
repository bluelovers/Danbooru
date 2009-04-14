class PoolUpdate < ActiveRecord::Base
  belongs_to :pool
  
  def updater_name
    User.find_name(user_id)
  end
  
  def sanitized_ip_addr
    ip_addr.to_s.sub(/\d+\.\d+$/, "x.x")
  end
end
