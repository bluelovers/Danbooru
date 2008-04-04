class ServerKey < ActiveRecord::Base
  def self.[](key)
    foo = find_by_name(key)
    
    if foo
      return foo.value
    else
      raise nil
    end
  end
end
