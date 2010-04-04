module TagMethods
  module CacheMethods
    def self.included(m)
      m.after_save :update_cache
    end

    def update_cache
      Cache.put("tag_type:#{name}", tag_type)
    end
  end
end
