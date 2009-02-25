require 'digest/sha1'

class User < ActiveRecord::Base
  class AlreadyFavoritedError < Exception; end

  module UserBlacklistMethods
    # TODO: I don't see the advantage of normalizing these. Since commas are illegal
    # characters in tags, they can be used to separate lines (with whitespace separating
    # tags). Denormalizing this into a field in users would save a SQL query.
    def self.included(m)
      m.after_save :commit_blacklists
      m.after_create :set_default_blacklisted_tags
      m.has_many :user_blacklisted_tags, :dependent => :delete_all
    end
    
    def blacklisted_tags=(blacklists)
      @blacklisted_tags = blacklists
    end

    def blacklisted_tags
      blacklisted_tags_array.join("\n") + "\n"
    end

    def blacklisted_tags_array
      user_blacklisted_tags.map {|x| x.tags}
    end

    def commit_blacklists
      if @blacklisted_tags
        user_blacklisted_tags.clear

        @blacklisted_tags.scan(/[^\r\n]+/).each do |tags|
          user_blacklisted_tags.create(:tags => tags)
        end
      end
    end
    
    def set_default_blacklisted_tags
      CONFIG["default_blacklists"].each do |b|
        UserBlacklistedTag.create(:user_id => self.id, :tags => b)
      end
    end
  end

  module UserAuthenticationMethods
    module ClassMethods
      def authenticate(name, pass)
        authenticate_hash(name, sha1(pass))
      end

      def authenticate_hash(name, pass)
        find(:first, :conditions => ["lower(name) = lower(?) AND password_hash = ?", name, pass])
      end

      def sha1(pass)
        Digest::SHA1.hexdigest("#{salt}--#{pass}--")
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
    end
  end
  
  module UserPasswordMethods
    attr_accessor :password
    
    def self.included(m)
      m.before_save :encrypt_password
      m.validates_length_of :password, :minimum => 5, :if => lambda {|rec| rec.password}
      m.validates_confirmation_of :password
    end
    
    def encrypt_password
      self.password_hash = User.sha1(password) if password
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
      execute_sql("UPDATE users SET password_hash = ? WHERE id = ?", User.sha1(pass), self.id)
      return pass
    end
  end

  module UserCountMethods
    module ClassMethods
      def fast_count
        return select_value_sql("SELECT row_count FROM table_data WHERE name = 'users'").to_i
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
      m.after_create :increment_count
      m.after_destroy :decrement_count
    end
    
    def increment_count
      connection.execute("update table_data set row_count = row_count + 1 where name = 'users'")
    end

    def decrement_count
      connection.execute("update table_data set row_count = row_count - 1 where name = 'users'")
    end
  end
  
  module UserNameMethods
    module ClassMethods
      def find_name_helper(user_id)
        if user_id.nil?
          return CONFIG["default_guest_name"]
        end

        user = find(:first, :conditions => ["id = ?", user_id], :select => "name")

        if user
          return user.name
        else
          return CONFIG["default_guest_name"]
        end
      end

      def find_name(user_id)
        if RAILS_ENV == "test"
          @cache = {}
        else
          @cache ||= {}
          @cache.clear if @cache.size > 30
          return @cache[user_id] if @cache[user_id]
        end
        
        @cache[user_id] = Cache.get("user_name:#{user_id}") do
          find_name_helper(user_id)
        end
      end
      
      def find_by_name(name)
        find(:first, :conditions => ["lower(name) = lower(?)", name])
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
      m.validates_length_of :name, :within => 2..20, :on => :create
      m.validates_format_of :name, :with => /\A[^\s;,]+\Z/, :on => :create, :message => "cannot have whitespace, commas, or semicolons"
      m.validates_uniqueness_of :name, :case_sensitive => false, :on => :create
      m.after_save :update_cached_name
    end
    
    def pretty_name
      name.tr("_", " ")
    end

    def update_cached_name
      Cache.put("user_name:#{id}", name)
    end
  end
  
  module UserApiMethods
    def api_attributes
      {:name => name, :id => id, :level => level, :created_at => created_at.strftime("%Y-%m-%d %H:%M")}
    end
    
    def to_xml(options = {})
      options[:indent] ||= 2      
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.user(api_attributes) do
        blacklisted_tags_array.each do |t|
          xml.blacklisted_tag(:tag => t)
        end
        
        tag_subscriptions.each do |ts|
          xml.subscription(:name => ts.name) do
            ts.tag_query.scan(/\S+/).each do |tag|
              xml.tag(:name => tag)
            end
          end
        end

        yield options[:builder] if block_given?
      end
    end

    def to_json(*args)
      api_attributes.merge(:blacklisted => blacklisted_tags_array, :subscriptions => tag_subscriptions.inject({}) {|all, x| all[x.name] = x.tag_query; all}).to_json(*args)
    end
  end
  
  module UserTagMethods
    def uploaded_tags(options = {})
      type = options[:type]

      uploaded_tags = Cache.get("uploaded_tags/#{id}/#{type}")
      return uploaded_tags unless uploaded_tags == nil

      if RAILS_ENV == "test"
        # disable filtering in test mode to simplify tests
        popular_tags = ""
      else
        popular_tags = select_values_sql("SELECT id FROM tags WHERE tag_type = #{CONFIG['tag_types']['General']} ORDER BY post_count DESC LIMIT 8").join(", ")
        popular_tags = "AND pt.tag_id NOT IN (#{popular_tags})" unless popular_tags.blank?
      end

      if type
        sql = <<-EOS
          SELECT (SELECT name FROM tags WHERE id = pt.tag_id) AS tag, COUNT(*) AS count
          FROM posts_tags pt, tags t, posts p
          WHERE p.user_id = #{id}
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
          WHERE p.user_id = #{id}
          AND p.id = pt.post_id
          #{popular_tags}
          GROUP BY pt.tag_id
          ORDER BY count DESC
          LIMIT 6
        EOS
      end

      uploaded_tags = select_all_sql(sql)

      Cache.put("uploaded_tags/#{id}/#{type}", uploaded_tags, 1.day)

      return uploaded_tags
    end
  end
  
  module UserPostMethods
    def recent_uploaded_posts
      Post.find_by_sql("SELECT p.* FROM posts p WHERE p.user_id = #{id} AND p.status <> 'deleted' ORDER BY p.id DESC LIMIT 5")
    end

    def recent_favorite_posts
      Post.find_by_sql("SELECT p.* FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id} AND p.status <> 'deleted' ORDER BY f.id DESC LIMIT 5")
    end

    def favorite_post_count(options = {})
      Post.count_by_sql("SELECT COUNT(p.id) FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id}")
    end
    
    def post_count
      @post_count ||= Post.count(:conditions => ["user_id = ? AND status = 'active'", id])
    end
  end
  
  module UserFavoriteMethods
    def add_favorite(post_id)
      if select_value_sql("SELECT 1 FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
        raise AlreadyFavoritedError
      else
        transaction do
          execute_sql("INSERT INTO favorites (post_id, user_id) VALUES (#{post_id}, #{id})")
          execute_sql("UPDATE posts SET fav_count = fav_count + 1, score = score + 1 WHERE id = #{post_id}")
        end
      end
    end

    def delete_favorite(post_id)
      if select_value_sql("SELECT 1 FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
        transaction do
          execute_sql("DELETE FROM favorites WHERE post_id = #{post_id} AND user_id = #{id}")
          execute_sql("UPDATE posts SET fav_count = fav_count - 1, score = score - 1 WHERE id = #{post_id}")
        end
      end
    end
  end
  
  module UserLevelMethods
    def self.included(m)
      m.attr_protected :level
      m.before_create :set_role
    end
    
    def pretty_level
      return CONFIG["user_levels"].invert[self.level]
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
    
    def has_permission?(record, foreign_key = :user_id)
      if is_mod_or_higher?
        true
      elsif record.respond_to?(foreign_key)
        record.__send__(foreign_key) == id
      else
        false
      end
    end

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
  end
  
  module UserInviteMethods
    class NoInvites < Exception ; end
    class HasNegativeRecord < Exception ; end
    
    def invite!(name, level)
      if invite_count <= 0
        raise NoInvites
      end
      
      if level.to_i >= CONFIG["user_levels"]["Contributor"]
        level = CONFIG["user_levels"]["Contributor"]
      end
      
      invitee = User.find_by_name(name)
      
      if invitee.nil?
        raise ActiveRecord::RecordNotFound
      end
      
      if UserRecord.exists?(["user_id = ? AND is_positive = false AND reported_by IN (SELECT id FROM users WHERE level >= ?)", invitee.id, CONFIG["user_levels"]["Mod"]]) && !is_admin?
        raise HasNegativeRecord
      end
      
      transaction do
        Post.find(:all, :conditions => ["user_id = ? AND status = 'pending'", id]).each do |post|
          post.approve!
        end
        invitee.level = level
        invitee.invited_by = id
        invitee.save
        decrement! :invite_count
      end
    end
    
    def self.included(m)
      m.attr_protected :invite_count
    end
  end
  
  module UserTagSubscriptionMethods
    def self.included(m)
      m.has_many :tag_subscriptions, :dependent => :delete_all, :order => "name"
    end
    
    def tag_subscriptions_text=(text)
      User.transaction do
        tag_subscriptions.clear
      
        text.scan(/\S+/).each do |new_tag_subscription|
          tag_subscriptions.create(:tag_query => new_tag_subscription)
        end
      end
    end
    
    def tag_subscriptions_text
      tag_subscriptions.map(&:tag_query).sort.join(" ")
    end
    
    def tag_subscription_posts(limit, name)
      TagSubscription.find_posts(id, name, limit)
    end
  end
  
  validates_presence_of :email, :on => :create if CONFIG["enable_account_email_activation"]
  validates_uniqueness_of :email, :case_sensitive => false, :on => :create, :if => lambda {|rec| not rec.email.empty?}
  before_create :set_show_samples if CONFIG["show_samples"]
  has_one :ban
  
  include UserBlacklistMethods
  include UserAuthenticationMethods
  include UserPasswordMethods
  include UserCountMethods
  include UserNameMethods
  include UserApiMethods
  include UserTagMethods
  include UserPostMethods
  include UserFavoriteMethods
  include UserLevelMethods
  include UserInviteMethods
  include UserTagSubscriptionMethods

  @salt = CONFIG["user_password_salt"]
  
  class << self
    attr_accessor :salt
  end
  
  # For compatibility with AnonymousUser class
  def is_anonymous?
    false
  end
  
  def invited_by_name
    self.class.find_name(invited_by)
  end
  
  def similar_users
    # This uses a naive cosine distance formula that is very expensive to calculate.
    # TODO: look into alternatives, like SVD.
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
    
    return select_all_sql(sql)
  end
  
  def set_show_samples
    self.show_samples = true
  end

  def self.generate_sql(params)
    return Nagato::Builder.new do |builder, cond|
      if params[:name]
        cond.add "name ILIKE ? ESCAPE E'\\\\'", "%" + params[:name].tr(" ", "_").to_escaped_for_sql_like + "%"
      end

      if params[:level] && params[:level] != "any"
        cond.add "level = ?", params[:level]
      end

      cond.add_unless_blank "id = ?", params[:id]
        
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
        builder.order "id DESC"
      end
    end.to_hash
  end
end

