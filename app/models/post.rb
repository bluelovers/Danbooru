Dir["#{RAILS_ROOT}/app/models/post/**/*.rb"].each {|x| require_dependency x}

class Post < ActiveRecord::Base
  STATUSES = %w(active pending flagged deleted)
  
  has_many :notes, :order => "id desc"
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  belongs_to :approver, :class_name => "User"
  attr_accessor :updater_ip_addr, :updater_user_id
  attr_protected :user_id, :score, :md5, :width, :height, :cached_tags, :fav_count, :file_ext, :has_children, :status, :sample_width, :sample_height, :change_seq, :approver_id, :tags_index, :ip_addr
  
  include PostSqlMethods
  include PostCommentMethods
  include PostImageStoreMethods
  include PostVoteMethods
  include PostTagMethods
  include PostCountMethods
  include PostCacheMethods
  include PostParentMethods
  include PostFileMethods
  include PostChangeSequenceMethods
  include PostRatingMethods
  include PostStatusMethods
  include PostApiMethods
  include PostModerationMethods
  
  def self.destroy_with_reason(id, reason, current_user)
    post = Post.find(id)
    Post.transaction do
      post.flag!(reason, current_user)
      post.reload
      post.delete!
    end
  end
  
  def flag!(reason, creator_id)
    update_attribute(:status, "flagged")
    
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
    
    self.status = "active"
    self.approver_id = approver_id
    save
  end
  
  # TODO: refactor or eliminate
  def favorited_by
    # Cache results
    if @favorited_by.nil?
      @favorited_by = User.find(:all, :joins => "JOIN favorites f ON f.user_id = users.id", :select => "users.name, users.id, users.created_at, users.level", :conditions => ["f.post_id = ?", id], :order => "f.id DESC")
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
      img_id = source[/(\d+(_m)?)\.\w+$/, 1]
      "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{img_id}"
    else
      source
    end
  end
end
