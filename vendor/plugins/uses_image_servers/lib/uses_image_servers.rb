module UsesImageServers
	def self.append_features(base) # :nodoc:
		super
		base.extend ClassMethods
	end

	module ClassMethods
		def uses_image_servers(options = {})
			class_eval do
				cattr_accessor :image_servers
				self.image_servers = options[:servers] || []
				include UsesImageServers::InstanceMethods
			end
		end
	end

	module InstanceMethods
		def select_random_server
			count = image_servers.size
			i = (count * rand()).to_i

			return image_servers[i] || ("http://" + CONFIG["server_host"])
		end

		def file_url
			if is_warehoused?
				prefix = select_random_server()
			else
				prefix = "http://" + CONFIG["server_host"]
			end

			prefix + "/data/%s/%s/%s" % [md5[0,2], md5[2,2], file_name]
		end

		def preview_url
			if is_warehoused?
				prefix = select_random_server()
			else
				prefix = "http://" + CONFIG["server_host"]
			end

			if image?
				prefix + "/data/preview/%s/%s/%s" % [md5[0,2], md5[2,2], md5 + ".jpg"]
			else
				prefix + "/data/preview/default.png"
			end
		end
	end
end

ActiveRecord::Base.class_eval do
	include UsesImageServers
end
