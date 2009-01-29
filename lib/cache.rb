module Cache
  def expire(options = {})
    tags = options[:tags]
    cache_version = Cache.get("$cache_version").to_i

    Cache.put("$cache_version", cache_version + 1)

    if tags
      tags.scan(/\S+/).each do |x|
        key = "tag:#{x}"
        key_version = Cache.get(key).to_i
        Cache.put(key, key_version + 1)
      end
    end
  end
    
  def incr(key)
    val = Cache.get(key)
    Cache.put(key, val.to_i + 1)
    ActiveRecord::Base.logger.debug('MemCache Incr %s' % [key])
  end
  
  def get(key, expiry = 0)
    if CONFIG["enable_caching"] == false
      if block_given?
        return yield
      else
        return nil
      end
    end
    
    begin
      start_time = Time.now
      value = MEMCACHE.get key
      elapsed = Time.now - start_time
      ActiveRecord::Base.logger.debug('MemCache Get (%0.6f)  %s' % [elapsed, key])
      if value.nil? and block_given? then
        value = yield
        MEMCACHE.add key, value, expiry
      end
      value
    rescue MemCache::MemCacheError => err
      ActiveRecord::Base.logger.debug "MemCache Error: #{err.message}"
      if block_given? then
        value = yield
        put key, value, expiry
      end
      value
    end
  end
  
  def put(key, value, expiry = 0)
    if CONFIG["enable_caching"] == false
      return value
    end
    
    begin
      start_time = Time.now
      MEMCACHE.set key, value, expiry
      elapsed = Time.now - start_time
      ActiveRecord::Base.logger.debug('MemCache Set (%0.6f)  %s' % [elapsed, key])
      value
    rescue MemCache::MemCacheError => err
      ActiveRecord::Base.logger.debug "MemCache Error: #{err.message}"
      nil
    end
  end
  
  def delete(key, delay = nil)
    if CONFIG["enable_caching"] == false
      return nil
    end
    
    begin
      start_time = Time.now
      MEMCACHE.delete key, delay
      elapsed = Time.now - start_time
      ActiveRecord::Base.logger.debug('MemCache Delete (%0.6f)  %s' % [elapsed, key])
      nil
    rescue MemCache::MemCacheError => err
      ActiveRecord::Base.logger.debug "MemCache Error: #{err.message}"
      nil
    end
  end
  
  module_function :get
  module_function :expire
  module_function :incr
  module_function :put
  module_function :delete
end
