module Cache
  def self.expire(options = {})
    if !CONFIG["enable_anonymous_safe_post_mode"] || options[:rating] == 's' || options[:update_post] || options[:destroy_post]
      # If safe post mode is disabled, then always expire the tag.
      #
      # If we've enabled safe post mode, and if the record is rated safe, 
      # then regardless of whether we're creating, destroying, or updating, 
      # we need to expire the cache.
      #
      # If the record is not work safe, then we don't need to expire the
      # cache if we're creating a new record (since anonymous users
      # wouldn't be able to see it anyway). So only expire if we're
      # destroying or updating, which might imply that we're marking a
      # safe post as not-safe.
      #
      # Here's the logic proof for this. 
      # Let:
      #   s = safe post mode
      #   r = rating is safe
      #   u = we're updating a post
      #   d = we're destroying a post
      #
      # ~s | (s & (r | u | d))
      # (~s | s) & (~s | (r | u | d))
      # T & (~s | r | u | d)
      # ~s | r | u | d
      
      options[:tags].scan(/\S+/).each do |x|
        key = "tag:#{x}"
        if CACHE.get(key, true) == nil
          CACHE.set(key, 0)
        end
        CACHE.incr(key)
      end

      $cache_version += 1
      CACHE.set("$cache_version", $cache_version)
    end
  end
end
