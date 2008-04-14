module PostMethods
  module CommentMethods
    def recent_comments
      Comment.find(:all, :conditions => ["post_id = ?", id], :order => "id desc", :limit => 6).reverse
    end

    def comment_count
      @comment_count ||= Comment.count(:conditions => ["post_id = ?", id])
    end
  end
end
