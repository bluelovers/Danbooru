class ServerKey
  def self.[](key)
    begin
      ActiveRecord::Base.connection.select_value("SELECT value FROM server_keys WHERE key = '#{key}'")
    rescue Exception
      nil
    end
  end
end
