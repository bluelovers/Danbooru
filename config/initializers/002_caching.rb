if CONFIG["enable_caching"]
  require 'memcache_util'
  require 'cache'
  require 'memcache_util_store'

  unless defined?(MEMCACHE)
    MEMCACHE = MemCache.new :c_threshold => 10_000, :compression => true, :debug => false, :namespace => CONFIG["app_name"], :readonly => false, :urlencode => false
    MEMCACHE.servers = CONFIG["memcache_servers"]
  end
end
