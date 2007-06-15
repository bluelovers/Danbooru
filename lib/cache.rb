module Cache
  def self.expire(options = {})
    if CONFIG["expire_method"] == :on_create_or_destroy && (options[:create_post] || options[:destroy_post])
      if CONFIG["enable_anonymous_safe_post_mode"] == false || options[:rating] == 's'
        options[:tags].scan(/\S+/).each do |x|
          key = "tag:#{x}"
          if CACHE.get(key) == nil
            CACHE.set(key, 0)
          end
          CACHE.incr(key)
        end
      end
    end
    
    if CONFIG["expire_method"] == :on_update && (options[:create_post] || options[:destroy_post] || options[:update_post])
      if CONFIG["enable_anonyous_safe_post_mode"] == false || options[:rating] == 's'
        options[:tags].scan(/\S+/).each do |x|
          key = "tag:#{x}"
          if CACHE.get(key) == nil
            CACHE.set(key, 0)
          end
          CACHE.incr(key)
        end
      end
    end
  end
end
