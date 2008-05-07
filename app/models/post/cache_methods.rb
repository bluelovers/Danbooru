module PostCacheMethods
  def self.included(m)
    m.after_save :expire_cache
    m.after_destroy :expire_cache
  end
  
  def expire_cache
    reload
    Cache.expire(:tags => cached_tags)
  end
end
