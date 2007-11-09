module Cache
  def expire(options = {})
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
  
  module_function :expire
end
