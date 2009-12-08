class Post < ActiveRecord::Base
  STATUSES = %w(active pending flagged deleted)
  
  has_many :notes, :order => "id desc"
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  belongs_to :approver, :class_name => "User"
  attr_accessor :updater_ip_addr, :updater_user_id
  attr_protected :user_id, :score, :md5, :width, :height, :cached_tags, :fav_count, :file_ext, :has_children, :status, :sample_width, :sample_height, :change_seq, :approver_id, :tags_index, :ip_addr
  
  include PostMethods::SqlMethods
  include PostMethods::CommentMethods
  include PostMethods::ImageStoreMethods
  include PostMethods::VoteMethods
  include PostMethods::TagMethods
  include PostMethods::CountMethods
  include PostMethods::CacheMethods
  include PostMethods::ParentMethods
  include PostMethods::FileMethods
  include PostMethods::ChangeSequenceMethods
  include PostMethods::RatingMethods
  include PostMethods::StatusMethods
  include PostMethods::ApiMethods
  include PostMethods::ModerationMethods
  include PostMethods::DeletionMethods
  include PostMethods::FlagMethods
  
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

  def active_notes
    notes.select {|x| x.is_active?}
  end
  
  def can_be_seen_by?(user)
    CONFIG["can_see_post"].call(user, self)
  end
  
  def normalized_source
    if source =~ /pixiv\.net\/img\//
      img_id = source[/(\d+)(_m|_p\d+)?\.\w+$/, 1]
      if $2 =~ /_p/
        "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=#{img_id}"
      else
        "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{img_id}"
      end
    else
      source
    end
  end
end
