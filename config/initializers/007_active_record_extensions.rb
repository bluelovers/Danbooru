module Danbooru
  module ActiveRecordExtensions
    def without_timeout
      connection.execute("SET STATEMENT_TIMEOUT = 0")
      yield
    ensure
      connection.execute("SET STATEMENT_TIMEOUT = 10000")
    end
    
    def with_timeout(n)
      connection.execute("SET STATEMENT_TIMEOUT = #{n}")
      yield
    ensure
      connection.execute("SET STATEMENT_TIMEOUT = 10000")
    end
  end
end

class ActiveRecord::Base
  extend Danbooru::ActiveRecordExtensions
end
