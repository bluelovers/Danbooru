module PostParentMethods
  module ClassMethods
    def update_has_children(post_id)
      has_children = Post.exists?(["parent_id = ? AND status <> 'deleted'", post_id])
      execute_sql("UPDATE posts SET has_children = ? WHERE id = ?", has_children, post_id)
    end
    
    def recalculate_has_children
      transaction do
        execute_sql("UPDATE posts SET has_children = false WHERE has_children = true")
        execute_sql("UPDATE posts SET has_children = true WHERE id IN (SELECT parent_id FROM posts WHERE parent_id IS NOT NULL AND status <> 'deleted')")
      end
    end

    def set_parent(post_id, parent_id, old_parent_id = nil)
      if old_parent_id.nil?
        old_parent_id = select_value_sql("SELECT parent_id FROM posts WHERE id = ?", post_id)
      end
      
      if parent_id.to_i == post_id.to_i || parent_id.to_i == 0
        parent_id = nil
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
    self.old_parent_id = parent_id
    self[:parent_id] = pid
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
