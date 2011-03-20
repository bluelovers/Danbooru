class Post < ActiveRecord::Base
  STATUSES = %w(active pending flagged deleted)
  
  has_many :notes, :order => "id desc"
  has_and_belongs_to_many :pools
  has_many :flags, :class_name => "PostFlag"
  has_many :appeals, :class_name => "PostAppeal"
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
    @favorited_by ||= User.find(:all, :joins => "JOIN favorites f ON f.user_id = users.id", :select => "users.name, users.id, users.created_at, users.level", :conditions => ["f.post_id = ?", id], :order => "f.id DESC")
  end

  def favorited_by_hash
    @favorited_by_hash ||= User.select_all_sql("SELECT users.name, users.id FROM users JOIN favorites f ON f.user_id = users.id WHERE f.post_id = #{id} ORDER BY f.id DESC")
  end

  def author
    return User.find_name(user_id)
  end

  def active_notes
    notes.select {|x| x.is_active?}
  end
  
  def active_notes_hash
    @active_notes_hash ||= Note.select_all_sql("SELECT * FROM notes WHERE post_id = #{id} AND is_active = TRUE")
  end
  
  def can_be_seen_by?(user)
    CONFIG["can_see_post"].call(user, self)
  end
  
  def normalized_source
    if source =~ /pixiv\.net\/img\//
      img_id = source[/(\d+)(_s|_m|(_big)?_p\d+)?\.[\w\?]+\s*$/, 1]

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
