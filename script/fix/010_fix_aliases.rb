#!/usr/bin/env ruby
require File.dirname(__FILE__) + "/../../config/environment"

ActiveRecord::Base.connection.execute("SET statement_timeout = 0")

TagAlias.find_each do |ta|
  TagAlias.__send__(:with_exclusive_scope) do
    Tag.recalculate_post_count(ta.name)
    if ta.alias_tag.post_count != 0
      print "#{ta.name}: #{ta.alias_tag.post_count} -> "
      TagAlias.fix(ta.name)
      puts "#{ta.alias_tag.post_count}"
    end

    ta.expire_cache
    ta.expire_remote_cache
  end
end
