module Votable
	def self.append_features(base) # :nodoc:
		super
		base.extend ClassMethods
	end

	module ClassMethods
		def votable(options = {})
			class_eval do
				include Votable::InstanceMethods
			end
		end
	end

	module InstanceMethods
		def vote!(score, ip_addr)
			if self.last_voter_ip == ip_addr
				return false
			else
				connection.execute("UPDATE posts SET score = %s, last_voter_ip = '%s' WHERE id = %s" % [self.score + score, ip_addr, self.id])
			end

			return true
		end
	end
end

ActiveRecord::Base.class_eval do
	include Votable
end
