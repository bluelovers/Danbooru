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
require 'aws/s3' if [:amazon_s3, :local_flat_with_amazon_s3_backup].include?(CONFIG["image_store"])
require 'danbooru_image_resizer/danbooru_image_resizer'
require 'superredcloth'
require 'html_4_tags'
require 'google_chart' if CONFIG["enable_reporting"]
require 'core_extensions'

if CONFIG["session_secret_key"] == "This should be at least 30 characters long"
  ActiveRecord::Base.logger.error "ERROR: Session secret key was not changed. Look in config/local_config.rb"
  raise "Session secret key was not changed"
end
