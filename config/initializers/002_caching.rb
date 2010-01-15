unless defined?(MEMCACHE)
  MEMCACHE = MemCache.new :c_threshold => 10_000, :compression => true, :debug => false, :namespace => CONFIG["app_name"].gsub(/[^A-Za-z0-9]/, "_"), :readonly => false, :urlencode => false
  MEMCACHE.servers = CONFIG["memcache_servers"]
end
