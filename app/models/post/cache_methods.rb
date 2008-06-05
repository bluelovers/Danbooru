module PostCacheMethods
  def self.included(m)
    m.after_save :expire_cache
    m.after_destroy :expire_cache
  end
  
  def expire_cache
    # Have to call this twice in order to expire tags that may have been removed
    Cache.expire(:tags => cached_tags)
    reload
    Cache.expire(:tags => cached_tags)
  end
end
