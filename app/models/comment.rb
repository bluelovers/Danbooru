class Comment < ActiveRecord::Base
  validates_format_of :body, :with => /\S/, :message => 'has no content'
  belongs_to :post
  belongs_to :user
  after_save :update_last_commented_at
  after_destroy :update_last_commented_at
  attr_accessor :do_not_bump_post

  def update_last_commented_at
    return if self.do_not_bump_post == "1"
    
    comment_count = connection.select_value("SELECT COUNT(*) FROM comments WHERE post_id = #{self.post_id}").to_i

    if comment_count < CONFIG["comment_threshold"]
      connection.execute("UPDATE posts SET last_commented_at = (SELECT created_at FROM comments WHERE post_id = #{self.post_id} ORDER BY created_at DESC LIMIT 1) WHERE posts.id = #{self.post_id}")
    end
  end

  def author
    if user_id
      connection.select_value("SELECT name FROM users WHERE id = #{self.user_id}")
    else
      CONFIG["default_guest_name"]
    end
  end

  def to_xml(options = {})
    {:id => id, :created_at => created_at, :post_id => post_id, :creator_id => user_id, :body => body}.to_xml(options.merge(:root => "comment"))
  end

  def to_json(options = {})
    {:id => id, :created_at => created_at, :post_id => post_id, :creator_id => user_id, :body => body}.to_json(options)
  end
end
