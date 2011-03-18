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
          post.delete!
        end
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
    end
    
    def delete_from_database
      delete_file
      execute_sql("DELETE FROM posts WHERE id = ?", id)
    end
  end
end
