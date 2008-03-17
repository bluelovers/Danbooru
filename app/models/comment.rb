class Comment < ActiveRecord::Base
  validates_format_of :body, :with => /\S/, :message => 'has no content'
  belongs_to :post
  belongs_to :user
  after_save :update_last_commented_at
  after_destroy :update_last_commented_at
  after_save :expire_cache
  after_destroy :expire_cache
  attr_accessor :do_not_bump_post
  
  def self.generate_sql(params)
    return Nagato::Builder.new do |builder, cond|
      cond.add_unless_blank "post_id = ?", params[:post_id]
    end.to_hash
  end

  def update_last_commented_at
    return if self.do_not_bump_post == "1"
    
    comment_count = connection.select_value("SELECT COUNT(*) FROM comments WHERE post_id = #{self.post_id}").to_i

    if comment_count < CONFIG["comment_threshold"]
      connection.execute("UPDATE posts SET last_commented_at = (SELECT created_at FROM comments WHERE post_id = #{self.post_id} ORDER BY created_at DESC LIMIT 1) WHERE posts.id = #{self.post_id}")
    end
  end

  def author
    return User.find_name(self.user_id)
  end
  
  def pretty_author
    author.tr("_", " ")
  end
  
  def expire_cache
    Cache.expire(:post_id => self.post_id)
  end
  
  def api_attributes
    return {
      :id => id, 
      :created_at => created_at, 
      :post_id => post_id, 
      :creator => author, 
      :creator_id => user_id, 
      :body => body
    }
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "comment"))
  end

  def to_json(options = {})
    return api_attributes.to_json(options)
  end
end
