module PostMethods
  module DeletionMethods
    module ClassMethods
      def destroy_with_reason(id, reason, current_user)
        post = Post.find(id)
        Post.transaction do
          if post.flags.empty?
            post.flag!(reason, current_user)
          end
          post.reload
          post.delete!(current_user.id)
        end
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
    end
    
    def undelete!(user_id)
      execute_sql("UPDATE posts SET status = ?, approver_id = ? WHERE id = ?", "active", user_id, id)
      Post.update_has_children(parent_id) if parent_id
      ModAction.create(:description => "undeleted post ##{id}", :user_id => user_id)
    end

    def delete!(user_id)
      give_favorites_to_parent
      update_attribute(:status, "deleted")
      Post.update_has_children(parent_id) if parent_id
      flags.each {|x| x.update_attribute(:is_resolved, true)}
      ModAction.create(:description => "deleted post ##{id}", :user_id => user_id)
    end
        
    def delete_from_database(user_id)
      delete_file
      execute_sql("DELETE FROM posts WHERE id = ?", id)
      ModAction.create(:description => "permanently deleted post ##{id}", :user_id => user_id)
    end
  end
end
