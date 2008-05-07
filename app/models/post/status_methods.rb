module PostStatusMethods
  def self.included(m)
    m.before_destroy :update_status_on_destroy
  end

  def update_status_on_destroy
    # Can't use update_attributes here since this method is wrapped inside of a destroy call
    execute_sql("UPDATE posts SET status = ? WHERE id = ?", "deleted", id)
    
    if flag_detail
      flag_detail.update_attributes(:is_resolved => true)
    end
    
    return false
  end

  def status=(s)
    return if s == status
    write_attribute(:status, s)
    touch_change_seq!
  end
end
