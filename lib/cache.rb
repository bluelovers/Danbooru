module Cache
  def self.expire(actions = {})
    if CONFIG["expire_method"] == :on_create_or_destroy && (actions[:create_post] || actions[:destroy_post])
      $cache_version += 1
      Cache.put("$cache_version", $cache_version)
    end
    
    if CONFIG["expire_method"] == :on_update && (actions[:create_post] || actions[:destroy_post] || actions[:update_post])
      $cache_version += 1
      Cache.put("$cache_version", $cache_version)
    end
  end
end
