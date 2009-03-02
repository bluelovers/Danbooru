module PostModerationMethods
  def mod_hide!(user_id)
    unless ModQueuePost.exists?(["user_id = ? AND post_id = ?", user_id, id])
      ModQueuePost.create(:user_id => user_id, :post_id => id)
    end
  end
  
  def mod_hidden_count
    ModQueuePost.count(:conditions => ["post_id = ?", id])
  end
end
