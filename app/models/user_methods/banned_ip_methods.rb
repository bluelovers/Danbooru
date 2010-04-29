module UserMethods
  module BannedIpMethods
    def self.included(m)
      m.validate :validate_ip_addr_is_not_banned
    end
    
    def validate_ip_addr_is_not_banned
      if BannedIp.is_banned?(ip_addr)
        self.errors.add_to_base("This IP address is banned and cannot create new accounts")
        return false
      end
    end
  end
end
