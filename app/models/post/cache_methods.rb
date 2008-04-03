module PostMethods
  module CacheMethods
    def self.included(m)
      m.after_save :expire_cache
      m.after_destroy :expire_cache
    end
    
    def expire_cache
      Cache.expire(:tags => cached_tags, :post_id => id, :md5 => md5)
    end
  end
end