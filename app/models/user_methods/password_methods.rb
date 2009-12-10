module UserMethods
  module PasswordMethods
    attr_accessor :password
    
    def self.included(m)
      m.before_save :encrypt_password
      m.validates_length_of :password, :minimum => 5, :if => lambda {|rec| rec.password}
      m.validates_confirmation_of :password
    end
    
    def encrypt_password
      self.password_hash = User.sha1(password) if password
    end
    
    def reset_password
      consonants = "bcdfghjklmnpqrstvqxyz"
      vowels = "aeiou"
      pass = ""

      4.times do
        pass << consonants[rand(21), 1]
        pass << vowels[rand(5), 1]
      end

      pass << rand(100).to_s
      execute_sql("UPDATE users SET password_hash = ? WHERE id = ?", User.sha1(pass), self.id)
      return pass
    end
  end
end
