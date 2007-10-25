class FlaggedPost < ActiveRecord::Base
  validates_uniqueness_of :post_id
  
  def self.flag(post_id, reason, resolved = false)
    user_id = connection.select_value("select user_id from posts where id = #{post_id.to_i}")
    create(:post_id => post_id, :reason => reason, :user_id => user_id, :is_resolved => resolved)
  end
  
  def self.unflag(post_id)
    connection.execute("update flagged_posts set is_resolved = true where post_id = #{post_id.to_i}")
  end
  
  def uploader_name
    connection.select_value("select name from users where is = #{self.user_id}")
  end
end
