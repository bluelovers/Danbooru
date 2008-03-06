require 'digest/sha1'

class User < ActiveRecord::Base
  class AlreadyFavoritedError < Exception; end

  attr_protected :level, :name
  attr_accessor :password
  if CONFIG["enable_account_email_activation"]
    validates_presence_of :email, :on => :create
  end
  validates_presence_of :ip_addr, :on => :create
  validates_length_of :password, :minimum => 5, :if => lambda {|rec| rec.password}
  validates_length_of :name, :within => 2..20, :on => :create
  validates_format_of :password, :with => /\d/, :if => lambda {|rec| rec.password}, :message => "must have at least one number"
  validates_format_of :name, :with => /\A[^\s;,]+\Z/, :on => :create, :message => "cannot have whitespace, commas, or semicolons"
  validates_uniqueness_of :name, :case_sensitive => false, :on => :create
  validates_uniqueness_of :email, :case_sensitive => false, :on => :create, :if => lambda {|rec| not rec.email.empty?}
  validates_confirmation_of :password
  before_save :encrypt_password
  before_create :set_role
  after_create :increment_count
  after_destroy :decrement_count
  has_one :ban
  
  # Defines various convenience methods for finding out the user's level
  CONFIG["user_levels"].each do |name, value|
    normalized_name = name.downcase.gsub(/ /, "_")
    define_method("is_#{normalized_name}?") do
      self.level == value
    end
    
    define_method("is_#{normalized_name}_or_higher?") do
      self.level >= value
    end
    
    define_method("is_#{normalized_name}_or_lower?") do
      self.level <= value
    end
  end

  @salt = CONFIG["password_salt"]
  
  class << self
    attr_accessor :salt

    def fast_count
      return connection.select_value("SELECT row_count FROM table_data WHERE name = 'users'").to_i
    end
  
    def authenticate(name, pass)
      authenticate_hash(name, sha1(pass))
    end

    def authenticate_hash(name, pass)
      find(:first, :conditions => ["lower(name) = lower(?) AND password_hash = ?", name, pass])
    end
  
    if CONFIG["enable_account_email_activation"]
      def confirmation_hash(name)
        Digest::SHA256.hexdigest("~-#{name}-~#{User.salt}")
      end
    end

    def find_people_who_favorited(post_id)
      User.find(:all, :joins => User.sanitize_sql(["JOIN favorites f ON f.user_id = users.id WHERE f.post_id = ?", post_id]), :order => "lower(name) ASC", :select => "users.*")
    end
  
    def sha1(pass)
      Digest::SHA1.hexdigest("#{salt}--#{pass}--")
    end
    
    def find_name_helper(user_id)
      user = User.find(:first, :conditions => ["id = ?", user_id], :select => "name")
      
      if user
        return user.name
      else
        return CONFIG["default_guest_name"]
      end
    end
    
    def find_name(user_id)
      if CONFIG["enable_caching"]
        return Cache.get("user_name:#{user_id}") do
          find_name_helper(user_id)
        end
      else
        find_name_helper(user_id)
      end
    end
  end
  
  # For compatibility with AnonymousUser class
  def is_anonymous?
    false
  end

  def pretty_name
    self.name.tr("_", " ")
  end

  def pretty_level
    return CONFIG["user_levels"].invert[self.level]
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
    
    if CONFIG["enable_caching"]
      uploaded_tags = Cache.get("uploaded_tags/#{self.id}/#{type}")
      return uploaded_tags unless uploaded_tags == nil
    end
    
    popular_tags = connection.select_values("select id from tags order by post_count desc limit 8").join(", ")
    popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?

    if type
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, tags t, posts p
        WHERE p.user_id = #{self.id}
        AND p.id = pt.post_id
        AND pt.tag_id = t.id
        #{popular_tags}
        AND t.tag_type = #{type.to_i}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 6
      EOS
    else
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, posts p
        WHERE p.user_id = #{self.id}
        AND p.id = pt.post_id
        #{popular_tags}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 6
      EOS
    end
    
    uploaded_tags = connection.select_all(sql)
    
    if CONFIG["enable_caching"]
      Cache.put("uploaded_tags/#{self.id}/#{type}", uploaded_tags, 1.day)
    end
    
    return uploaded_tags
  end

  def favorite_tags(options = {})
    type = options[:type]
    
    if CONFIG["enable_caching"]
      favorite_tags = Cache.get("favorite_tags/#{self.id}/#{type}")
      return favorite_tags unless favorite_tags == nil
    end
    
    popular_tags = connection.select_values("select id from tags order by post_count desc limit 8").join(", ")
    popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?

    if type
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, tags t, favorites f
        WHERE f.user_id = #{self.id}
        AND f.post_id = pt.post_id
        AND pt.tag_id = t.id
        #{popular_tags}
        AND t.tag_type = #{type.to_i}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 6
      EOS
    else
      sql = <<-EOS
        SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
        FROM posts_tags pt, favorites f
        WHERE f.user_id = #{self.id}
        AND f.post_id = pt.post_id
        #{popular_tags}
        GROUP BY pt.tag_id
        ORDER BY count DESC
        LIMIT 6
      EOS
    end
    
    favorite_tags = connection.select_all(sql)
    
    if CONFIG["enable_caching"]
      Cache.put("favorite_tags/#{self.id}/#{type}", favorite_tags, 1.day)
    end
    
    return favorite_tags
  end
  
  def similar_users
    sql = <<-EOS
      SELECT 
        f0.user_id as user_id,
        COUNT(*) / (SELECT sqrt((SELECT COUNT(*) FROM favorites WHERE user_id = f0.user_id) * (SELECT COUNT(*) FROM favorites WHERE user_id = #{id}))) AS similarity
      FROM
        favorites f0,
        favorites f1,
        users u
      WHERE
        f0.post_id = f1.post_id
        AND f1.user_id = #{id}
        AND f0.user_id <> #{id}
        AND u.id = f0.user_id
      GROUP BY f0.user_id
      ORDER BY similarity DESC
      LIMIT 6
    EOS
    
    return connection.select_all(sql)
  end
  
  def set_role
    if User.fast_count == 0
      self.level = CONFIG["user_levels"]["Admin"]
    elsif CONFIG["enable_account_email_activation"]
      self.level = CONFIG["user_levels"]["Unactivated"]
    else
      self.level = CONFIG["starting_level"]
    end
    
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
        Cache.expire(:post_id => post_id)
      end
    end
  end

  def delete_favorite(post_id)
    if connection.select_value("SELECT 1 FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
      transaction do
        connection.execute("DELETE FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
        connection.execute("UPDATE posts SET fav_count = fav_count - 1, score = score - 1 WHERE id = #{post_id}")
        Cache.expire(:post_id => post_id)
      end
    end
  end
  
  def uploaded_posts(offset, limit, options = {})
    extra_sql = ""
    
    Post.find_by_sql("SELECT p.* FROM posts p WHERE p.user_id = #{id} #{extra_sql} ORDER BY p.id DESC OFFSET #{offset} LIMIT #{limit}")
  end

  def favorite_posts(offset, limit, options = {})
    extra_sql = ""
    
    Post.find_by_sql("SELECT p.* FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id} #{extra_sql} ORDER BY f.id DESC OFFSET #{offset} LIMIT #{limit}")
  end

  def favorite_post_count(options = {})
    extra_sql = ""
    
    Post.count_by_sql("SELECT COUNT(p.id) FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id} #{extra_sql}")
  end
  
  def has_permission?(record, foreign_key = :user_id)
    if self.is_mod_or_higher?
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
      pass << consonants[rand(21), 1]
      pass << vowels[rand(5), 1]
    end
    
    pass << rand(100).to_s

    connection.execute(User.sanitize_sql(["UPDATE users SET password_hash = ? WHERE id = ?", User.sha1(pass), self.id]))
    return pass
  end
  
  def increment_count
    connection.execute("update table_data set row_count = row_count + 1 where name = 'users'")
  end
  
  def decrement_count
    connection.execute("update table_data set row_count = row_count - 1 where name = 'users'")
  end
  
  def to_xml(options = {})
    {:name => self.name, :blacklisted_tags => self.blacklisted_tags, :id => self.id}.to_xml(options.merge(:root => "user"))
  end

  def to_json(options = {})
    {:name => self.name, :blacklisted_tags => self.blacklisted_tags, :id => self.id}.to_json(options)
  end
  
  def self.generate_sql(params)
    b = Nagato::Builder.new do |builder|
      builder.where do |cond|
        if params[:name]
          cond.add "name ILIKE ? ESCAPE '\\\\'", "%" + params[:name].to_escaped_for_sql_like + "%"
        end
      
        if params[:id]      
          cond.add "id = ?", params[:id]
        end
        
        if params[:level] && params[:level] != "any"
          cond.add "level = ?", params[:level]
        end
      end

      case params[:order]
      when "name"
        builder.order "lower(name)"

      when "posts"
        builder.order "(SELECT count(*) FROM posts WHERE user_id = users.id) DESC"

      when "favorites"
        builder.order "(SELECT count(*) FROM favorites WHERE user_id = users.id) DESC"

      when "notes"
        builder.order "(SELECT count(*) FROM note_versions WHERE user_id = users.id) DESC"

      else
        builder.order "created_at DESC"
      end
    end
    
    return b.to_hash
  end
end

