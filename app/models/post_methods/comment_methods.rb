module PostMethods
  module CommentMethods
    def self.included(m)
      m.has_many :comments, :order => "id" do
        def hidden(current_user)
          find(:all, :conditions => ["score < ?", current_user.comment_threshold])
        end
      end
    end
  
    def recent_comments
      Comment.find(:all, :conditions => ["post_id = ?", id], :order => "id desc", :limit => 6).reverse
    end
    
    def hidden_comment_count(current_user)
      comments.hidden(current_user).count
    end
  end
end
