require "#{RAILS_ROOT}/config/default_config"
require "#{RAILS_ROOT}/config/local_config"

CONFIG["url_base"] ||= "http://" + CONFIG["server_host"]

%w(session_secret_key user_password_salt).each do |key|
  CONFIG[key] = ServerKey[key] if ServerKey[key]
end

ActionController::Base.session = {:session_key => CONFIG["app_name"], :secret => CONFIG["session_secret_key"]}

# Vendor libraries
require 'image_size'
require 'json/add/core'
require 'json/add/rails'
require 'memcache_util'

# Custom libraries
require 'danbooru_image_resizer/danbooru_image_resizer'
require 'html_4_tags'
require 'core_extensions'
require 'download'
require 'dtext'
require 'cache'
