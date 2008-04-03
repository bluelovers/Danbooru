module PostMethods
  module CacheMethods
    def expire_cache
      Cache.expire(:tags => cached_tags, :post_id => id, :md5 => md5)
    end
  end
end