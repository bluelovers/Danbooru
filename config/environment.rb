# Be sure to restart your webserver when you modify this file.

# Uncomment below to force Rails into production mode
# (Use only when you can't set environment variables through your web/app server)
# ENV['RAILS_ENV'] = 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
require 'default_config'
require 'local_config'

Rails::Initializer.run do |config|
  # Skip frameworks you're not going to use
  config.frameworks -= [ :action_web_service ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/app/services )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug
  config.log_level = :info

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  #config.active_record.default_timezone = :utc

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby

  # See Rails::Configuration for more options
end

# Add new inflection rules using the following format
# (all these examples are active by default):
#Inflector.inflections do |inflect|
#end

ActiveRecord::Base.allow_concurrency = false

ActionMailer::Base.default_charset = "utf-8"
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address => "localhost",
  :port => 25,
  :domain => "localhost"
}

ExceptionNotifier.exception_recipients = [CONFIG["admin_contact"]]
ExceptionNotifier.sender_address = CONFIG["admin_contact"]
ExceptionNotifier.email_prefix = "[" + CONFIG["app_name"] + "] "

require 'base64'
require 'diff/lcs/array'
require 'image_size'
require 'ipaddr'
require 'open-uri'
require 'socket'
require 'time'
require 'uri'
require 'acts_as_versioned'
require 'net/http'
require 'core_extensions'
require 'aws/s3' if CONFIG["image_store"] == :amazon_s3
require 'danbooru_image_resizer/danbooru_image_resizer'

begin
  require 'superredcloth'
rescue LoadError
  require 'redcloth'
end

if CONFIG["enable_caching"]
  require 'memcache_util'
  require 'cache'
  require 'memcache_util_store'
  
  CACHE = MemCache.new :c_threshold => 10_000, :compression => true, :debug => false, :namespace => CONFIG["app_name"], :readonly => false, :urlencode => false
  CACHE.servers = CONFIG["memcache_servers"]
  $cache_version = CACHE.get("$cache_version", true).to_i
  ActionController::Base.session_store = :mem_cache_store
  ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.merge!({"cache" => CACHE})
end
