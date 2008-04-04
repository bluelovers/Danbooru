require 'digest/sha1'

class ServerKey < ActiveRecord::Base
end

class CreateServerKeys < ActiveRecord::Migration
  def self.up
    create_table :server_keys do |t|
      t.column :name, :string, :null => false
      t.column :value, :text
    end
    
    add_index :server_keys, :name, :unique => true
    
    ServerKey.create(:name => "session_secret_key", :value => (CONFIG["session_secret_key"] || Digest::SHA1.hexdigest(rand(10 ** 32))))
    ServerKey.create(:name => "user_password_salt", :value => (CONFIG["password_salt"] || Digest::SHA1.hexdigest(rand(10 ** 32))))
  end

  def self.down
    drop_table :server_keys
  end
end
