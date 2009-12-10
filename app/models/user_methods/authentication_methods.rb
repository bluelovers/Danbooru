module UserMethods
  module AuthenticationMethods
    module ClassMethods
      def authenticate(name, pass)
        authenticate_hash(name, sha1(pass))
      end

      def authenticate_hash(name, pass)
        find(:first, :conditions => ["lower(name) = lower(?) AND password_hash = ?", name, pass])
      end

      def sha1(pass)
        Digest::SHA1.hexdigest("#{salt}--#{pass}--")
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
    end
  end
end
