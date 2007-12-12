module Cache
  def expire(options = {})
    tags = options[:tags]
    post_id = options[:post_id]
    cache_version = Cache.get("$cache_version").to_i

    Cache.put("$cache_version", cache_version + 1)

    if tags
      tags.scan(/\S+/).each do |x|
        key = "tag:#{x}"
        key_version = Cache.get(key).to_i
        Cache.put(key, key_version + 1)
      end
    end

    if post_id
      Cache.delete("p/s/#{post_id}")
    end
  end
  
  module_function :expire
end
