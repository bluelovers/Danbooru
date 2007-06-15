module Cache
  def self.expire(actions = {})
    if CONFIG["expire_method"] == :on_create_or_destroy && (actions[:create_post] || actions[:destroy_post])
      actions[:tags].scan(/\S+/).each do |x|
        key = "tag:#{x}"
        if CACHE.get(key) == nil
          CACHE.set(key, 0)
        end
        CACHE.incr(key)
      end
    end
    
    if CONFIG["expire_method"] == :on_update && (actions[:create_post] || actions[:destroy_post] || actions[:update_post])
      actions[:tags].scan(/\S+/).each do |x|
        key = "tag:#{x}"
        if CACHE.get(key) == nil
          CACHE.set(key, 0)
        end
        CACHE.incr(key)
      end
    end
  end
end
