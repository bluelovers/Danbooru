module PostMethods
  module CacheMethods
    def expire_cache
      unless self.is_pending?
        Cache.expire(:tags => self.cached_tags, :post_id => self.id, :md5 => self.md5)
      end
    end
  end
end