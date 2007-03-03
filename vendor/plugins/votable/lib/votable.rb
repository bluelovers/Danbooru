module Votable
	def self.append_features(base) # :nodoc:
		super
		base.extend ClassMethods
	end

	module ClassMethods
		def votable(options = {})
			class_eval do
				include Votable::InstanceMethods

				class AlreadyVotedError < Exception; end
			end
		end
	end

	module InstanceMethods
		def vote!(score, ip_addr)
			if self.last_voter_ip == ip_addr
				raise AlreadyVotedError
			else
				self.update_attributes(:score => self.score + score, :last_voter_ip => ip_addr)
			end
		end
	end
end

ActiveRecord::Base.class_eval do
	include Votable
end
