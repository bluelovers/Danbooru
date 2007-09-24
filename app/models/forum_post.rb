class ForumPost < ActiveRecord::Base
  has_many :children, :class_name => "ForumPost", :foreign_key => :parent_id, :order => "id"
  belongs_to :parent, :class_name => "ForumPost", :foreign_key => :parent_id
  belongs_to :creator, :class_name => "User", :foreign_key => :creator_id
  after_create :initialize_last_updated_by
  after_create :update_parent_on_create
  before_destroy :update_parent_on_destroy
  before_validation :validate_title
  validates_length_of :body, :minimum => 1, :message => "You need to enter a message"
  
  def validate_title
    if self.parent?
      if self.title.blank?
        self.errors.add :title, "missing"
        return false
      end
      
      if self.title !~ /\S/
        self.errors.add :title, "missing"
        return false
      end
    end
    
    return true
  end
  
  def initialize_last_updated_by
    if self.parent?
      update_attribute(:last_updated_by, self.creator_id)
    end
  end
  
  def update_parent_on_destroy
    unless self.parent?
      p = self.parent
      p.update_attributes(:response_count => p.response_count - 1)
    end
  end
  
  def update_parent_on_create
    unless self.parent?
      p = self.parent
      p.update_attributes(:updated_at => self.updated_at, :response_count => p.response_count + 1, :last_updated_by => self.creator_id)
    end
  end
  
  def last_updater
    if self.last_updated_by
      User.find(self.last_updated_by).name
    else
      CONFIG["default_guest_name"]
    end
  end
  
  def updated?(user_id)
    if CONFIG["enable_turbo_mode"]
      return false
    end
    
    fpv = ForumPostView.find(:first, :conditions => ["user_id = ? AND forum_post_id = ?", user_id, self.id])
    return fpv == nil || fpv.last_viewed_at < self.updated_at
  end
  
  def parent?
    return self.parent_id == nil
  end
  
  def root
    if self.parent?
      return self
    else
      return ForumPost.find(self.parent_id)
    end
  end
  
  def root_id
    if self.parent?
      return self.id
    else
      return self.parent_id
    end
  end
  
  def author
    if self.creator
      self.creator.name
    else
      CONFIG["default_guest_name"]
    end
  end
  
  def self.updated_since?(user_id)
    return false
    
    fp = ForumPostView.find(:first, :conditions => ["forum_posts_user_views.user_id = ? AND forum_posts_user_views.last_viewed_at < forum_posts.updated_at AND forum"])
    return fp != nil
  end

  def to_xml(options = {})
    {:id => id, :created_at => created_at, :updated_at => updated_at, :parent_id => parent_id, :creator_id => creator_id, :response_count => response_count, :title => title, :last_updated_by => last_updated_by, :body => body}.to_xml(options.merge(:root => "forum_post"))
  end

  def to_json(options = {})
    {:id => id, :created_at => created_at, :updated_at => updated_at, :parent_id => parent_id, :creator_id => creator_id, :response_count => response_count, :title => title, :last_updated_by => last_updated_by, :body => body}.to_json(options)
  end
end
