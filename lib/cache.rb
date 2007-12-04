module Cache
  def expire(options = {})
    if options[:tags]
      options[:tags].scan(/\S+/).each do |x|
        key = "tag:#{x}"
        if CACHE.get(key, true) == nil
          CACHE.set(key, 0)
        end
        CACHE.incr(key)
      end
  
      $cache_version = CACHE.incr("$cache_version")
    elsif options[:post_id]
      CACHE.set("p/s/#{options[:post_id]}", nil)
    end
  end
  
  module_function :expire
end
