class ForumPostView < ActiveRecord::Base
	set_table_name "forum_posts_user_views"

	class << self
		def updated?(user_id)
			if CONFIG["enable_forum_update_notices"] == false
				return false
			end

			sql = <<-EOS
				SELECT COALESCE((
					SELECT 1
					FROM forum_posts fp
					WHERE fp.parent_id IS NULL
					AND fp.id NOT IN (
						SELECT fpuv.forum_post_id
						FROM forum_posts_user_views fpuv
						WHERE fpuv.user_id = #{user_id}
					)
					LIMIT 1
				), (
					SELECT 1
					FROM forum_posts fp, forum_posts_user_views fpuv
					WHERE fp.id = fpuv.forum_post_id
					AND fp.parent_id IS NULL
					AND fp.updated_at > fpuv.last_viewed_at
					AND fpuv.user_id = #{user_id}
					LIMIT 1
				))
			EOS

			return connection.select_value(sql) != nil
		end
	end
end
