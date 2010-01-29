class Comment < ActiveRecord::Base
  class VotingError < Exception ; end
  
  validates_format_of :body, :with => /\S/, :message => 'has no content'
  belongs_to :post
  belongs_to :user
  has_many :votes, :class_name => "CommentVote"
  after_save :update_last_commented_at
  after_destroy :update_last_commented_at
  attr_protected :post_id, :user_id, :score, :text_search_index
  attr_accessor :do_not_bump_post
  
  def self.generate_sql(params)
    return Nagato::Builder.new do |builder, cond|
      cond.add_unless_blank "post_id = ?", params[:post_id]
    end.to_hash
  end
  
  def self.recent
    all(:limit => 6, :order => "id desc")
  end

  def update_last_commented_at
    return if self.do_not_bump_post
    
    comment_count = connection.select_value("SELECT COUNT(*) FROM comments WHERE post_id = #{post_id}").to_i
    if comment_count <= CONFIG["comment_threshold"]
      connection.execute("UPDATE posts SET last_commented_at = (SELECT created_at FROM comments WHERE post_id = #{post_id} ORDER BY created_at DESC LIMIT 1) WHERE posts.id = #{post_id}")
    end
  end

  def author
    return User.find_name(self.user_id)
  end
  
  def pretty_author
    author.tr("_", " ")
  end
  
  def can_be_voted_by?(user)
    !votes.exists?(["user_id = ?", user.id])
  end
  
  def vote!(user, n)
    if !user.can_comment_vote?
      raise VotingError.new("You can only vote ten times an hour on comments")
    elsif can_be_voted_by?(user)
      update_attribute(:score, score + n)
      votes.create(:user_id => user.id)
    else
      raise VotingError.new("You have already voted for this comment")
    end
  end
  
  def api_attributes
    return {
      :id => id, 
      :created_at => created_at.strftime("%Y-%m-%d %H:%M"), 
      :post_id => post_id, 
      :creator => author, 
      :creator_id => user_id, 
      :body => body,
      :score => score
    }
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "comment"))
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end
end
