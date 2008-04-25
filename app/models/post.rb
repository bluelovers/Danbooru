Dir["#{RAILS_ROOT}/app/models/post_methods/**/*.rb"].each {|x| require_dependency x}

class Post < ActiveRecord::Base
  STATUSES = %w(active pending flagged deleted)
  
  has_many :comments, :order => "id"
  has_many :notes, :order => "id desc"
  has_many :tag_history, :class_name => "PostTagHistory", :table_name => "post_tag_histories", :order => "id desc"
  has_one :flag_detail, :class_name => "FlaggedPostDetail"
  belongs_to :user
  before_create :touch_change_seq!
  after_save :update_change_seq
  attr_accessor :increment_change_seq
  
  extend PostMethods::SqlMethods
  include PostMethods::CommentMethods
  extend PostMethods::ImageStoreMethods
  include PostMethods::VoteMethods
  include PostMethods::TagMethods
  include PostMethods::CountMethods
  include PostMethods::CacheMethods if CONFIG["enable_caching"]
  include PostMethods::ParentMethods if CONFIG["enable_parent_posts"]
  include PostMethods::FileMethods

  before_destroy :update_status_on_destroy
  attr_accessor :updater_ip_addr, :updater_user_id, :old_rating

  image_store(CONFIG["image_store"])
    
  def self.destroy_with_reason(id, reason, current_user)
    post = Post.find(id)
    post.flag!(reason, current_user)
    post.reload
    post.destroy
  end
  
  def validate_content_type
    if self.file_ext.empty?
      errors.add_to_base("No file received")
      return false
    end

    unless %w(jpg png gif swf).include?(self.file_ext.downcase)
      errors.add(:file, "is an invalid content type: " + self.file_ext.downcase)
      return false
    end
  end
  
  def touch_change_seq!
    self.increment_change_seq = true
    return true
  end

  def update_change_seq
    return if self.increment_change_seq.nil?
    connection.execute("UPDATE posts SET change_seq = nextval('post_change_seq') WHERE id = #{self.id}")
    self.change_seq = connection.select_value("SELECT change_seq FROM posts WHERE id = #{self.id}")
  end

  def flag!(reason, creator_id)
    update_attributes(:status => "flagged")
    
    if flag_detail
      flag_detail.update_attributes(:reason => reason, :user_id => creator_id)
    else
      FlaggedPostDetail.create(:post_id => id, :reason => reason, :user_id => creator_id, :is_resolved => false)
    end
  end
  
  def approve!
    if flag_detail
      flag_detail.update_attributes(:is_resolved => true)
    end
    
    update_attributes(:status => "active")
  end

  def update_status_on_destroy
    update_attributes(:status => "deleted")
    
    if flag_detail
      flag_detail.update_attributes(:is_resolved => true)
    end
    
    return false
  end

  def favorited_by
    # Cache results
    if @favorited_by.nil?
      @favorited_by = User.find(:all, :joins => "JOIN favorites f ON f.user_id = users.id", :select => "users.name, users.id", :conditions => ["f.post_id = ?", self.id], :order => "lower(users.name)")
    end

    return @favorited_by
  end

  def status=(s)
    return if s == status
    write_attribute(:status, s)
    touch_change_seq!
  end

  def rating=(r)
    if r == nil && !new_record?
      return
    end

    if is_rating_locked?
      return
    end

    r = r.to_s.downcase[0, 1]

    if %w(q e s).include?(r)
      new_rating = r
    else
      new_rating = 'q'
    end

    return if rating == new_rating
    self.old_rating = rating
    write_attribute(:rating, new_rating)
    touch_change_seq!
  end


# Returns either the author's name or the default guest name.
  def author
    return User.find_name(user_id)
  end

  def self.find_by_tags(tags, options = {})
    return find_by_sql(Post.generate_sql(tags, options))
  end

  def pretty_rating
    case rating
    when "q"
      return "Questionable"

    when "e"
      return "Explicit"

    when "s"
      return "Safe"
    end
  end
  
  def api_attributes
    return {
      :id => id, 
      :tags => cached_tags, 
      :created_at => created_at, 
      :creator_id => user_id, 
      :change => change_seq,
      :source => source, 
      :score => score, 
      :md5 => md5, 
      :file_url => file_url, 
      :preview_url => preview_url, 
      :preview_width => preview_dimensions()[0],
      :preview_height => preview_dimensions()[1],
      :sample_url => sample_url,
      :sample_width => sample_width || width,
      :sample_height => sample_height || height,
      :rating => rating, 
      :has_children => has_children, 
      :parent_id => parent_id, 
      :status => status,
      :width => width,
      :height => height
    }
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "post"))
  end
  
  def delete_from_database
    connection.execute("delete from posts where id = #{self.id}")
  end
  
  def active_notes
    notes.select {|x| x.is_active?}
  end
  
  STATUSES.each do |x|
    define_method("is_#{x}?") do
      return status == x
    end
  end
  
  def can_view?(user)
    return CONFIG["can_see_post"].call(user, self)
  end
  
  def can_be_seen_by?(user)
    return can_view?(user)
  end
end
