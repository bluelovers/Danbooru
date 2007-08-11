require 'digest/sha1'

class User < ActiveRecord::Base
  class AlreadyFavoritedError < Exception; end

	before_create :set_role
	before_create :set_invite_count
	before_create :crypt_password
	before_validation_on_update :crypt_unless_empty
	validates_confirmation_of :password
	validates_format_of :email, :with => /\A[^@\s]+@[^\s]+\.[^\s]+\Z/, :message => 'Invalid e-mail address'
	has_many :invites
	attr_protected :level
	
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

	def set_invite_count
		if CONFIG["enable_invites"]
			self.invite_count = CONFIG["starting_invite_count"]
		end
	end

  def new_password=(pass)
    self.password = pass
  end

  def new_password
    ""
  end

	def set_role
		if User.fast_count == 0
			self.level = LEVEL_ADMIN
		elsif CONFIG["enable_account_email_activation"]
			self.level = LEVEL_UNACTIVATED
		else
			self.level = LEVEL_MEMBER
		end
	end

	def validate_on_create
		self.errors.add(:name, "too short") if name.size < 2
		self.errors.add(:name, "cannot have spaces") if name =~ /\s/
		self.errors.add(:name, "already exists") if User.find(:first, :conditions => ["lower(name) = lower(?)", name])
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

	# Authenticate a user.
	def self.authenticate(name, pass)
		authenticate_hash(name, sha1(pass))
	end

	# Authenticate a user against a hashed password. Note that the password must be salted!
	def self.authenticate_hash(name, pass)
		find(:first, :conditions => ["lower(name) = lower(?) AND password = ?", name, pass])
	end

	def self.find_people_who_favorited(post_id)
		User.find(:all, :joins => User.sanitize_sql(["JOIN favorites f ON f.user_id = users.id WHERE f.post_id = ?", post_id]), :order => "lower(name) ASC", :select => "users.*")
	end

	def reset_password!
		consonants = "bcdfghjklmnpqrstvqxyz"
		vowels = "aeiou"
		pass = ""

		4.times do
			pass << consonants[rand(21).to_i, 1]
			pass << vowels[rand(5), 1]
		end

		connection.execute(User.sanitize_sql(["UPDATE users SET password = ? WHERE id = ?", User.sha1(pass), self.id]))
		return pass
	end

	def to_xml(options = {})
		{:name => self.name, :id => self.id}.to_xml(options.merge(:root => "user"))
	end

	def to_json(options = {})
		{:name => self.name, :id => self.id}.to_json(options)
	end

	protected
	# Apply SHA1 encryption to the supplied password. We will additionally surround the password with a salt for additional security.
	def self.sha1(pass)
		Digest::SHA1.hexdigest("#{salt}--#{pass}--")
	end

	# Before saving the record to database we will crypt the password using SHA1. We never store the actual password in the DB.
	def crypt_password
		write_attribute :password, self.class.sha1(password)
	end

	# If the record is updated we will check if the password is empty. If its empty we assume that the user didn't want to change his password and just reset it to the old value.
	def crypt_unless_empty
		if self.password.empty?
			user = self.class.find(self.id)
			self.password_confirmation = nil
			self.password = user.password
		else
			self.password_confirmation = self.class.sha1(password_confirmation)
			self.password = self.class.sha1(password)
		end
	end
end
