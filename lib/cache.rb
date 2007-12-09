module Cache
  def expire(options = {})
    if options[:tags]
      options[:tags].scan(/\S+/).each do |x|
        key = "tag:#{x}"
        key_version = Cache.get(key) {0}
        Cache.put(key, key_version + 1)
      end
    end

    if options[:post_id]
      Cache.put("p/s/#{options[:post_id]}", nil)
    else  
      cache_version = Cache.get("$cache_version") {0}
      Cache.put("$cache_version", cache_version + 1)
    end
  end
  
  module_function :expire
end
