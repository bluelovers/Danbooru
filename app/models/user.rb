require 'digest/sha1'

class User < ActiveRecord::Base
  class AlreadyFavoritedError < Exception; end

  attr_protected :level, :name
  attr_accessor :password
  if CONFIG["enable_account_email_activation"]
    validates_presence_of :email, :on => :create
  end
  validates_length_of :password, :minimum => 5, :if => lambda {|rec| rec.password}
  validates_length_of :name, :minimum => 2, :on => :create
  validates_format_of :password, :with => /\d/, :if => lambda {|rec| rec.password}, :message => "must have at least one number"
  validates_format_of :name, :with => /\A[^\s;,]+\Z/, :on => :create, :message => "cannot have whitespace, commas, or semicolons"
  validates_uniqueness_of :name, :case_sensitive => false, :on => :create
  validates_uniqueness_of :email, :case_sensitive => false, :on => :create
  validates_confirmation_of :password
  before_save :encrypt_password
  before_create :set_role
  
  # Users are in one of seven possible roles:
  LEVEL_UNACTIVATED = -1
  LEVEL_BLOCKED = 0
  LEVEL_JAILED = 1
  LEVEL_MEMBER = 2
  LEVEL_PRIVILEGED = 3
  LEVEL_MOD = 10
  LEVEL_ADMIN = 20

  # Please change the salt to something else, every application should use a different one
  @@salt = CONFIG["password_salt"]
  cattr_accessor :salt

  def self.fast_count
    return connection.select_value("SELECT row_count FROM table_data WHERE name = 'users'").to_i
  end
  
  def self.authenticate(name, pass)
    authenticate_hash(name, sha1(pass))
  end

  def self.authenticate_hash(name, pass)
    find(:first, :conditions => ["lower(name) = lower(?) AND password_hash = ?", name, pass])
  end
  
  if CONFIG["enable_account_email_activation"]
    def self.confirmation_hash(name)
      Digest::SHA256.hexdigest("~-#{name}-~#{User.salt}")
    end
  end

  def self.find_people_who_favorited(post_id)
    User.find(:all, :joins => User.sanitize_sql(["JOIN favorites f ON f.user_id = users.id WHERE f.post_id = ?", post_id]), :order => "lower(name) ASC", :select => "users.*")
  end
  
  def self.sha1(pass)
    Digest::SHA1.hexdigest("#{salt}--#{pass}--")
  end
  
  def pretty_level
    case self.level
    when LEVEL_UNACTIVATED
      "Unactivated"
      
    when LEVEL_BLOCKED
      "Blocked"
      
    when LEVEL_JAILED
      "Jailed"
      
    when LEVEL_MEMBER
      "Member"
      
    when LEVEL_PRIVILEGED
      "Privileged"
      
    when LEVEL_MOD
      "Moderator"
      
    when LEVEL_ADMIN
      "Administrator"
    end
  end

  def invited_by_ancestors
    ancestors = []
    parent = self.invited_by

    while parent != nil
      parent = User.find(parent)
      ancestors << parent
      parent = parent.invited_by
    end

    return ancestors
  end
  
  def uploaded_tags(options = {})
    type = options[:type]
    start_date = options[:start_date]
    end_date = options[:end_date]
    popular_tags = connection.select_values("select id from tags order by post_count desc limit 8").join(", ")
    popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?
    
    if start_date && end_date
      date_sql = "p.created_at BETWEEN ? AND ?"
      params = [start_date, end_date]
    else
      date_sql = "true"
      params = []
    end

    if type
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, tags t, posts p
        WHERE p.user_id = #{self.id}
        AND p.id = pt.post_id
        AND #{date_sql}
        AND pt.tag_id = t.id
        #{popular_tags}
        AND t.tag_type = #{type.to_i}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 10
      EOS
    else
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, posts p
        WHERE p.user_id = #{self.id}
        AND p.id = pt.post_id
        AND #{date_sql}
        #{popular_tags}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 10
      EOS
    end
    
    return connection.select_all(User.sanitize_sql([sql, *params]))
  end

  def favorite_tags(options = {})
    type = options[:type]
    start_date = options[:start_date]
    end_date = options[:end_date]
    popular_tags = connection.select_values("select id from tags order by post_count desc limit 8").join(", ")
    popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?
    
    if start_date && end_date
      date_sql = "f.created_at BETWEEN ? AND ?"
      params = [start_date, end_date]
    else
      date_sql = "true"
      params = []
    end

    if type
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, tags t, favorites f
        WHERE f.user_id = #{self.id}
        AND f.post_id = pt.post_id
        AND #{date_sql}
        AND pt.tag_id = t.id
        #{popular_tags}
        AND t.tag_type = #{type.to_i}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 10
      EOS
    else
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, favorites f
        WHERE f.user_id = #{self.id}
        AND f.post_id = pt.post_id
        AND #{date_sql}
        #{popular_tags}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 10
      EOS
    end
    
    return connection.select_all(User.sanitize_sql([sql, *params]))
  end
  
  def similar_users
    sql = <<-EOS
      SELECT 
        f0.user_id,
        COUNT(*) / (SELECT sqrt((SELECT COUNT(*) FROM favorites WHERE user_id = f0.user_id) * (SELECT COUNT(*) FROM favorites WHERE user_id = #{id}))) AS similarity
      FROM
        favorites f0,
        favorites f1
      WHERE
        f0.post_id = f1.post_id
        AND f1.user_id = #{id}
        AND f0.user_id <> #{id}
      GROUP BY f0.user_id
      ORDER BY similarity DESC
      LIMIT 50
    EOS
    
    users = connection.select_all(sql)
    sum = users.inject(0) {|sum, x| sum + x["similarity"].to_f}
    users.each do |x|
      x["similarity"] = x["similarity"].to_f / sum
    end

    return users[0, 10]
  end
  
  def set_role
    if User.fast_count == 0
      self.level = LEVEL_ADMIN
    elsif CONFIG["enable_account_email_activation"]
      self.level = LEVEL_UNACTIVATED
    else
      self.level = CONFIG["starting_level"]
    end
    
    self.ip_addr = ''
    self.last_logged_in_at = Time.now
  end

  def encrypt_password
    self.password_hash = User.sha1(password) if password
  end

  def add_favorite(post_id)
    if connection.select_value("SELECT 1 FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
      raise AlreadyFavoritedError
    else
      transaction do
        connection.execute("INSERT INTO favorites (post_id, user_id) VALUES (#{post_id}, #{id})")
        connection.execute("UPDATE posts SET fav_count = fav_count + 1, score = score + 1 WHERE id = #{post_id}")
      end
    end
  end

  def delete_favorite(post_id)
    if connection.select_value("SELECT 1 FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
      transaction do
        connection.execute("DELETE FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
        connection.execute("UPDATE posts SET fav_count = fav_count - 1, score = score - 1 WHERE id = #{post_id}")
      end
    end
  end
  
  def uploaded_posts(offset, limit, options = {})
    extra_sql = ""
    
    if options[:hide_unsafe_posts]
      extra_sql = "AND p.is_pending = FALSE AND p.rating = 's'"
    end
    
    Post.find_by_sql("SELECT p.* FROM posts p WHERE p.user_id = #{id} #{extra_sql} ORDER BY p.id DESC OFFSET #{offset} LIMIT #{limit}")
  end

  def favorite_posts(offset, limit, options = {})
    extra_sql = ""
    
    if options[:hide_unsafe_posts]
      extra_sql = "AND p.is_pending = FALSE AND p.rating = 's'"
    end
    
    Post.find_by_sql("SELECT p.* FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id} #{extra_sql} ORDER BY f.id DESC OFFSET #{offset} LIMIT #{limit}")
  end

  def favorite_post_count(options = {})
    extra_sql = ""
    
    if options[:hide_unsafe_posts]
      extra_sql = "AND p.is_pending = FALSE AND p.rating = 's'"
    end
    
    Post.count_by_sql("SELECT COUNT(p.id) FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id} #{extra_sql}")
  end

  def activated?
    self.level > LEVEL_UNACTIVATED
  end

  def blocked?
    self.level <= LEVEL_BLOCKED
  end

  def jailed?
    self.level == LEVEL_JAILED
  end
  
  def member?
    self.level >= LEVEL_MEMBER
  end

  def privileged?
    self.level >= LEVEL_PRIVILEGED
  end
  
  def mod?
    self.level >= LEVEL_MOD
  end
  
  def admin?
    self.level >= LEVEL_ADMIN
  end
  
  def has_permission?(record, foreign_key = :user_id)
    if self.mod?
      true
    elsif record.respond_to?(foreign_key)
      record.__send__(foreign_key) == self.id
    else
      false
    end
  end

  def update_forum_view(forum_post_id)
    view = ForumPostView.find(:first, :conditions => ["user_id = ? AND forum_post_id = ?", self.id, forum_post_id])
    if view == nil
      ForumPostView.create(:user_id => self.id, :forum_post_id => forum_post_id, :last_viewed_at => Time.now)
    else
      view.update_attribute(:last_viewed_at, Time.now)
    end
  end

  def reset_password
    consonants = "bcdfghjklmnpqrstvqxyz"
    vowels = "aeiou"
    pass = ""

    4.times do
      pass << consonants[rand(21).to_i, 1]
      pass << vowels[rand(5), 1]
    end

    connection.execute(User.sanitize_sql(["UPDATE users SET password_hash = ? WHERE id = ?", User.sha1(pass), self.id]))
    return pass
  end

  def to_xml(options = {})
    {:name => self.name, :id => self.id}.to_xml(options.merge(:root => "user"))
  end

  def to_json(options = {})
    {:name => self.name, :id => self.id}.to_json(options)
  end
end
