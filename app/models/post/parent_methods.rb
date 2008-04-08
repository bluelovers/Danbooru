module PostMethods
  module ParentMethods
    attr_accessor :old_parent_id
    
    def self.included(m)
      m.after_save :update_parent
      m.validate :validate_parent
      m.before_destroy :give_favorites_to_parent
    end
    
    def self.set_parent(post_id, parent_id)
      old_parent_id = select_sql("SELECT parent_id FROM posts WHERE id = ?", post_id)
      execute_sql("UPDATE posts SET parent_id = ? WHERE id = ?", parent_id, post_id)
      old_parent_has_children = Post.exists?(["parent_id = ?", old_parent_id])
      execute_sql("UPDATE posts SET has_children = ? WHERE id = ?", old_parent_has_children, old_parent_id)
      execute_sql("UPDATE posts SET has_children = ? WHERE id = ?", true, parent_id)
    end
    
    def validate_parent
      errors.add("parent_id") unless parent_id.nil? or Post.exists?(parent_id)
    end
  
    def parent_id=(pid)
      self.old_parent_id = self.parent_id
      
      if pid == id
        self[:parent_id] = nil
      else
        self[:parent_id] = pid
      end
    end
    
    def update_has_children(id)
      children = Post.exists?(["parent_id = #{id} AND status <> 'deleted'"]).to_s
      execute_sql("UPDATE posts SET has_children = ? WHERE id = ?", children, id)
    end

    def update_parent
      update_has_children(old_parent_id) if old_parent_id
      update_has_children(parent_id) if parent_id
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