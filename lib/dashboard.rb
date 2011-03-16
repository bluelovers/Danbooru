class Dashboard
  class CommentActivity
    attr_reader :comment, :count
    
    def initialize(hash)
      @comment = Comment.find(hash["comment_id"])
      @count = hash["count"]
    end
  end
  
  class PostActivity
    attr_reader :post, :count
    
    def initialize(hash)
      @post = Post.find(hash["post_id"])
      @count = hash["count"]
    end
  end
  
  attr_reader :min_date
  
  def initialize(min_date)
    @min_date = min_date
  end
  
  def comment_activity(positive = false)
    if positive
      ActiveRecord::Base.select_all_sql("SELECT comment_votes.comment_id, count(*) FROM comment_votes JOIN comments ON comments.id = comment_votes.comment_id WHERE comment_votes.created_at > ? AND comments.score > 0 GROUP BY comment_votes.comment_id HAVING count(*) >= 3 ORDER BY count(*) DESC LIMIT 15", min_date).map {|x| CommentActivity.new(x)}
    else
      ActiveRecord::Base.select_all_sql("SELECT comment_votes.comment_id, count(*) FROM comment_votes JOIN comments ON comments.id = comment_votes.comment_id WHERE comment_votes.created_at > ? AND comments.score > 0 GROUP BY comment_votes.comment_id HAVING count(*) >= 3 ORDER BY count(*) DESC LIMIT 15", min_date).map {|x| CommentActivity.new(x)}
    end
  end
  
  def post_activity(positive = false)
    if positive
      ActiveRecord::Base.select_all_sql("SELECT post_votes.post_id, count(*) FROM post_votes JOIN posts ON posts.id = post_votes.post_id WHERE post_votes.created_at > ? AND posts.score > 0 GROUP BY post_votes.post_id HAVING count(*) >= 3 ORDER BY count(*) DESC LIMIT 15", min_date).map {|x| PostActivity.new(x)}
    else
      ActiveRecord::Base.select_all_sql("SELECT post_votes.post_id, count(*) FROM post_votes JOIN posts ON posts.id = post_votes.post_id WHERE post_votes.created_at > ? AND posts.score < 0 GROUP BY post_votes.post_id HAVING count(*) >= 3 ORDER BY count(*) DESC LIMIT 15", min_date).map {|x| PostActivity.new(x)}
    end
  end
end
