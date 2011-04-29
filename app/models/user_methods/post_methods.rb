module UserMethods
  module PostMethods
    def favorited_posts(limit, offset)
      post_ids = Favorite.select_values_sql("SELECT post_id FROM favorites WHERE user_id = ? ORDER BY id DESC LIMIT ? OFFSET ?", id, limit, offset).map(&:to_i)
      Post.find(:all, :conditions => ["id in (?)", post_ids], :order => Favorite.build_sql_order_clause("posts", post_ids))
    end
    
    def recent_uploaded_posts
      Post.find_by_sql("SELECT p.* FROM posts p WHERE p.user_id = #{id} AND p.status <> 'deleted' ORDER BY p.id DESC LIMIT 5")
    end

    def recent_favorite_posts
      favorited_posts(5, 0)
    end

    def favorite_post_count(options = {})
      Favorite.count(:conditions => ["user_id = ?", id])
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
