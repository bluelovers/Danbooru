module PostMethods
  module CommentMethods
    def recent_comments
      Comment.find(:all, :conditions => "post_id = #{self.id}", :order => "id desc", :limit => 6).reverse
    end

    def comment_count
      @comment_count ||= Comment.count_by_sql("SELECT COUNT(*) FROM comments WHERE post_id = #{self.id}")
      return @comment_count
    end
  end
end
