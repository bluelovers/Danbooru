module Cache
	def self.expire(actions = {})
		if actions[:create_post]
			$cache_version += 1
		end

		if actions[:destroy_post]
			$cache_version += 1
			Cache.delete("p/s/" + actions[:destroy_post].to_s)
		end

		if actions[:update_post]
			Cache.delete("p/s/" + actions[:update_post].to_s)
		end
	end
end
