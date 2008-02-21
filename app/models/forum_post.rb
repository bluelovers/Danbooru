class ForumPost < ActiveRecord::Base
  has_many :children, :class_name => "ForumPost", :foreign_key => :parent_id, :order => "id"
  belongs_to :parent, :class_name => "ForumPost", :foreign_key => :parent_id
  belongs_to :creator, :class_name => "User", :foreign_key => :creator_id
  after_create :initialize_last_updated_by
  after_create :update_parent_on_create
  before_destroy :update_parent_on_destroy
  before_validation :validate_lock
  before_validation :validate_title
  validates_length_of :body, :minimum => 1, :message => "You need to enter a message"
  
  def self.updated?(user)
    newest_topic = ForumPost.find(:first, :order => "updated_at desc", :limit => 1, :select => "updated_at", :conditions => ["parent_id is null"])
    return false if newest_topic == nil
    return newest_topic.updated_at > user.last_forum_topic_read_at
  end
  
  def self.lock(id, status)
    status = status ? true : false
    id = id.to_i
    connection.execute("UPDATE forum_posts SET is_locked = #{status} WHERE id = #{id}")
  end
  
  def self.stick(id, status)
    status = status ? true : false
    id = id.to_i
    connection.execute("UPDATE forum_posts SET is_sticky = #{status} WHERE id = #{id}")
  end
  
  def validate_lock
    if self.root.is_locked?
      self.errors.add_to_base("Thread is locked")
      return false
    end
    
    return true
  end
  
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
  
  def to_json
    {:body => self.body, :creator => self.author, :creator_id => self.creator_id, :id => self.id, :parent_id => self.parent_id, :title => self.title}.to_json
  end

  def to_xml(options = {})
    {:body => self.body.gsub(/\r\n|\r|\n/, '\\n'), :creator => self.author, :creator_id => self.creator_id, :id => self.id, :parent_id => self.parent_id, :title => self.title}.to_xml(options.merge(:root => "forum_post"))
  end
end
