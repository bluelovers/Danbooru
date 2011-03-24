module UserMethods
  module FavoriteMethods
    class FavoriteError < Exception; end

    def add_favorite(post_id)
      if select_value_sql("SELECT 1 FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
        raise FavoriteError.new("You've already favorited this post")
      else
        transaction do
          execute_sql("INSERT INTO favorites (post_id, user_id) VALUES (#{post_id}, #{id})")
          if is_privileged_or_higher?
            execute_sql("UPDATE posts SET fav_count = fav_count + 1, score = score + 1 WHERE id = #{post_id}")
          else
            execute_sql("UPDATE posts SET fav_count = fav_count + 1 WHERE id = #{post_id}")
          end
        end
      end
    end

    def delete_favorite(post_id)
      if select_value_sql("SELECT 1 FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
        transaction do
          execute_sql("DELETE FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
          if is_privileged_or_higher?
            execute_sql("UPDATE posts SET fav_count = fav_count - 1, score = score - 1 WHERE id = #{post_id}")
          else
            execute_sql("UPDATE posts SET fav_count = fav_count - 1 WHERE id = #{post_id}")
          end
        end
      end
    end
  end
end
