module Cache
  def expire(options = {})
    cache_version = Cache.get("$cache_version") {0}
    Cache.put("$cache_version", cache_version + 1)
    
    if options[:tags]
      options[:tags].scan(/\S+/).each do |x|
        key = "tag:#{x}"
        key_version = Cache.get(key) {0}
        Cache.put(key, key_version + 1)
      end
    end
  end
  
  module_function :expire
end
