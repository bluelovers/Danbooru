module PostMethods
  module ParentMethods
    module ClassMethods
      def update_has_children(post_id)
        has_children = Post.exists?(["parent_id = ? AND status <> 'deleted'", post_id])
        execute_sql("UPDATE posts SET has_children = ? WHERE id = ?", has_children, post_id)
      end

      def set_parent(post_id, parent_id, old_parent_id = nil)
        # TODO: Unnecessary calls are being made here. Example output:
        # SQL (0.000512)   SELECT parent_id FROM posts WHERE id = 223116
        # SQL (0.001174)   UPDATE posts SET parent_id = NULL WHERE id = 223116
        # Post Load (0.001072)   SELECT posts.id FROM posts WHERE (parent_id = NULL AND status <> 'deleted') LIMIT 1
        # SQL (0.000476)   UPDATE posts SET has_children = 'f' WHERE id = NULL
        # CACHE (0.000000)   SELECT posts.id FROM posts WHERE (parent_id = NULL AND status <> 'deleted') LIMIT 1
        # SQL (0.000457)   UPDATE posts SET has_children = 'f' WHERE id = NULL
        # SQL (0.000170)   COMMIT
        
        if old_parent_id.nil?
          old_parent_id = select_value_sql("SELECT parent_id FROM posts WHERE id = ?", post_id)
        end

        execute_sql("UPDATE posts SET parent_id = ? WHERE id = ?", parent_id, post_id)

        update_has_children(old_parent_id)
        update_has_children(parent_id)
      end
    end
    
    attr_accessor :old_parent_id
    
    def self.included(m)
      m.extend(ClassMethods)
      m.after_save :update_parent
      m.validate :validate_parent
      m.before_destroy :give_favorites_to_parent
    end
    
    def validate_parent
      errors.add("parent_id") unless parent_id.nil? or Post.exists?(parent_id)
    end
  
    def parent_id=(pid)
      self.old_parent_id = self.parent_id
      
      if pid.to_s.empty? or pid.to_i == id.to_i
        self[:parent_id] = nil
      else
        self[:parent_id] = pid
      end
    end
    
    def update_parent
      self.class.set_parent(id, parent_id, old_parent_id)
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