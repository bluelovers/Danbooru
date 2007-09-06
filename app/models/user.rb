require 'digest/sha1'

class User < ActiveRecord::Base
  class AlreadyFavoritedError < Exception; end

	attr_protected :level
  attr_accessor :password
  validates_presence_of :password, :on => :create
  validates_length_of :password, :minimum => 5, :if => lambda {|rec| rec.password}
  validates_length_of :name, :minimum => 2, :on => :create
  validates_format_of :password, :with => /\d/, :if => lambda {|rec| rec.password}, :message => "must have at least one number"
  validates_format_of :name, :with => /\A[^\s;,]+\Z/, :on => :create, :message => "cannot have whitespace, commas, or semicolons"
  validates_uniqueness_of :name, :case_sensitive => false, :on => :create
  validates_confirmation_of :password
  before_save :encrypt_password
	before_create :set_role
	
	# Users are in one of seven possible roles:
	LEVEL_UNACTIVATED = -1
	LEVEL_BLOCKED = 0
	LEVEL_VIEW_ONLY = 1
	LEVEL_MEMBER = 2
	LEVEL_SPECIAL = 3
	LEVEL_MOD = 10
	LEVEL_ADMIN = 20

	# Please change the salt to something else, every application should use a different one
	@@salt = 'choujin-steiner'
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

	def self.find_people_who_favorited(post_id)
		User.find(:all, :joins => User.sanitize_sql(["JOIN favorites f ON f.user_id = users.id WHERE f.post_id = ?", post_id]), :order => "lower(name) ASC", :select => "users.*")
	end
	
	def self.sha1(pass)
		Digest::SHA1.hexdigest("#{salt}--#{pass}--")
	end
	
	def set_role
		if User.fast_count == 0
			self.level = LEVEL_ADMIN
		elsif CONFIG["enable_account_email_activation"]
			self.level = LEVEL_UNACTIVATED
		else
			self.level = CONFIG["starting_level"]
		end
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

	def favorites(offset, limit)
		Post.find_by_sql("SELECT p.* FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id} ORDER BY p.id DESC OFFSET #{offset} LIMIT #{limit}")
	end

	def favorites_count
		Post.count_by_sql("SELECT COUNT(p.id) FROM posts p, favorites f WHERE p.id = f.post_id AND f.user_id = #{id}")
	end

	def activated?
		self.level > LEVEL_UNACTIVATED
	end
	
	def admin?
		self.level >= LEVEL_ADMIN
	end
	
	def mod?
		self.level >= LEVEL_MOD
	end
	
	def member?
		self.level >= LEVEL_VIEW_ONLY
	end
	
	def view_only?
		self.level == LEVEL_VIEW_ONLY
	end
	
	def blocked?
		self.level <= LEVEL_BLOCKED
	end

	def role?(role)
		case role
		when :admin
			self.level >= LEVEL_ADMIN

		when :mod
			self.level >= LEVEL_MOD

		when :member
			self.level >= LEVEL_MEMBER

		else
			false
		end
	end

	def has_permission?(record, foreign_key = :user_id)
		if self.mod?
			true
		elsif record.respond_to?(foreign_key)
			record[foreign_key] == self.id
		else
			false
		end
	end

	def update_forum_view!(forum_post_id)
		view = ForumPostView.find(:first, :conditions => ["user_id = ? AND forum_post_id = ?", self.id, forum_post_id])
		if view == nil
			ForumPostView.create(:user_id => self.id, :forum_post_id => forum_post_id, :last_viewed_at => Time.now)
		else
			view.update_attribute(:last_viewed_at, Time.now)
		end
	end

	def reset_password!
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
