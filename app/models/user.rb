require 'digest/sha1'

class User < ActiveRecord::Base
  include UserMethods::ApiMethods
  include UserMethods::AuthenticationMethods
  include UserMethods::BlacklistMethods
  include UserMethods::CountMethods
  include UserMethods::FavoriteMethods
  include UserMethods::ForumMethods
  include UserMethods::InviteMethods
  include UserMethods::LevelMethods
  include UserMethods::LimitMethods
  include UserMethods::NameMethods
  include UserMethods::PasswordMethods
  include UserMethods::PostMethods
  include UserMethods::SqlMethods
  include UserMethods::TagMethods
  include UserMethods::TagSubscriptionMethods
  include UserMethods::BannedIpMethods
  
  attr_accessor :ip_addr
  validates_presence_of :email, :on => :create if CONFIG["enable_account_email_activation"]
  validates_uniqueness_of :email, :case_sensitive => false, :on => :create, :if => lambda {|rec| not rec.email.empty?}
  before_create :initialize_show_samples if CONFIG["show_samples"]
  has_one :ban
  has_one :test_janitor
  has_many :favorites
  has_many :user_records
  
  @salt = CONFIG["user_password_salt"]
  
  class << self
    attr_accessor :salt
  end
  
  # For compatibility with AnonymousUser class
  def is_anonymous?
    false
  end
  
  def initialize_show_samples
    self.show_samples = true
  end
end

