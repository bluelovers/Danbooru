module PostMethods
  module CacheMethods
    def self.included(m)
      m.after_save :expire_cache
      m.after_destroy :expire_cache
    end
  
    def expire_cache
      # Have to call this twice in order to expire tags that may have been removed
      Cache.expire(:tags => old_cached_tags) if old_cached_tags
      Cache.expire(:tags => cached_tags)
      Cache.delete("tag_sidebar:post:true:#{id}")
      Cache.delete("tag_sidebar:post:false:#{id}")
    end
  end
end
