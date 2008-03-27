module PostMethods
  module ParentMethods
    def validate_parent
      errors.add("parent_id") unless parent_id.nil? or Post.exists?(parent_id)
    end
  
    def parent_id=(pid)
      @old_parent_id = self.parent_id
      if pid == id
        self[:parent_id] = nil
      else
        self[:parent_id] = pid
      end
    end

    def update_parent
      def update_has_children(id)
        children = Post.exists?(["parent_id = #{id} AND status <> 'deleted'"])? "true":"false"
        connection.execute("UPDATE posts SET has_children = #{children} WHERE id = #{id}")
      end

      update_has_children(@old_parent_id) if @old_parent_id
      update_has_children(self.parent_id) if self.parent_id
    end
  
    def give_favorites_to_parent
      return if parent_id.nil?

      transaction do
        # Don't trust cache for this.
        @favorited_by = nil
        favorited_by.map do |user|
          begin
            user.add_favorite(parent_id)
          rescue User::AlreadyFavoritedError
          end
          user.delete_favorite(id)
        end
      end
    end
  end
end