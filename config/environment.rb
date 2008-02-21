RAILS_GEM_VERSION = "2.0.2"

require File.join(File.dirname(__FILE__), 'boot')
require 'default_config'
require 'local_config'

CONFIG["url_base"] ||= "http://" + CONFIG["server_host"]

Rails::Initializer.run do |config|
  # Skip frameworks you're not going to use
  config.frameworks -= [:action_web_service]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/app/services )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug
  config.log_level = :info

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby
  
  config.action_controller.session = {:session_key => CONFIG["app_name"], :secret => CONFIG["session_secret_key"]}
end

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
require 'aws/s3' if CONFIG["image_store"] == :amazon_s3 || CONFIG["image_store"] == :local_flat_with_amazon_s3_backup
require 'danbooru_image_resizer/danbooru_image_resizer'
require 'superredcloth'
require 'html_4_tags'
require 'google_chart' if CONFIG["enable_reporting"]

if CONFIG["enable_caching"]
  require 'memcache_util'
  require 'cache'
  require 'memcache_util_store'
  
  CACHE = MemCache.new :c_threshold => 10_000, :compression => true, :debug => false, :namespace => CONFIG["app_name"], :readonly => false, :urlencode => false
  CACHE.servers = CONFIG["memcache_servers"]
end
