module UserMethods
  module PostMethods
    def recent_uploaded_posts
      Post.find_by_sql("SELECT p.* FROM posts p WHERE p.user_id = #{id} AND p.status <> 'deleted' ORDER BY p.id DESC LIMIT 5")
    end

    def recent_favorite_posts
      Post.find_by_sql("SELECT p.* FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id} AND p.status <> 'deleted' ORDER BY f.id DESC LIMIT 5")
    end

    def favorite_post_count(options = {})
      Post.count_by_sql("SELECT COUNT(p.id) FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id}")
    end

    def positive_scoring_post_count
      @positive_post_count ||= Post.count(:conditions => ["user_id = ? AND status = 'active' and score > 1", id])
    end
    
    def negative_scoring_post_count
      @negative_post_count ||= Post.count(:conditions => ["user_id = ? AND status = 'active' and score < -1", id])
    end
    
    def post_count
      @post_count ||= Post.count(:conditions => ["user_id = ? AND status = 'active'", id])
    end
  end
end
