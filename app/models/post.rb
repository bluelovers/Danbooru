Dir["#{RAILS_ROOT}/app/models/post/**/*.rb"].each {|x| require_dependency x}

class Post < ActiveRecord::Base
  STATUSES = %w(active pending flagged deleted)
  
  has_many :notes, :order => "id desc"
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  belongs_to :approver, :class_name => "User"
  attr_accessor :updater_ip_addr, :updater_user_id
  
  include PostSqlMethods
  include PostCommentMethods
  include PostImageStoreMethods
  include PostVoteMethods
  include PostTagMethods
  include PostCountMethods
  include PostCacheMethods if CONFIG["enable_caching"]
  include PostParentMethods if CONFIG["enable_parent_posts"]
  include PostFileMethods
  include PostChangeSequenceMethods
  include PostRatingMethods
  include PostStatusMethods
  include PostApiMethods
  
  def self.destroy_with_reason(id, reason, current_user)
    post = Post.find(id)
    post.flag!(reason, current_user)
    post.reload
    post.destroy
  end
  
  def flag!(reason, creator_id)
    update_attributes(:status => "flagged")
    
    if flag_detail
      flag_detail.update_attributes(:reason => reason, :user_id => creator_id)
    else
      FlaggedPostDetail.create!(:post_id => id, :reason => reason, :user_id => creator_id, :is_resolved => false)
    end
  end
  
  def approve!(approver_id)
    if flag_detail
      flag_detail.update_attributes(:is_resolved => true)
    end
    
    update_attributes(:status => "active", :approver_id => approver_id)
  end
  
  # TODO: refactor or eliminate
  def favorited_by
    # Cache results
    if @favorited_by.nil?
      @favorited_by = User.find(:all, :joins => "JOIN favorites f ON f.user_id = users.id", :select => "users.name, users.id", :conditions => ["f.post_id = ?", id], :order => "f.id DESC")
    end

    return @favorited_by
  end

  def author
    return User.find_name(user_id)
  end
  
  def delete_from_database
    delete_file
    execute_sql("DELETE FROM posts WHERE id = ?", id)
  end
  
  def active_notes
    notes.select {|x| x.is_active?}
  end
  
  STATUSES.each do |x|
    define_method("is_#{x}?") do
      return status == x
    end
  end
  
  def can_be_seen_by?(user)
    CONFIG["can_see_post"].call(user, self)
  end
  
  def normalized_source
    if source =~ /pixiv\.net\/img\//
      img_id = source[/(\d+)\.\w+$/, 1]
      "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{img_id}"
    else
      source
    end
  end
end
