module PostStatusMethods
  def delete!
    update_attribute(:status, "deleted")
    Post.update_has_children(parent_id) if parent_id
    flag_detail.update_attributes(:is_resolved => true) if flag_detail
  end

  def status=(s)
    return if s == status
    write_attribute(:status, s)
    touch_change_seq!
  end
  
  def undelete!
    execute_sql("UPDATE posts SET status = ? WHERE id = ?", "active", id)
    Post.update_has_children(parent_id) if parent_id
  end
end
