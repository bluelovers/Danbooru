#!/usr/bin/env ruby

require File.dirname(__FILE__) + "/../../config/environment"

Post.find_each(:conditions => ["GREATEST(width, height) IN (150, 600) AND source LIKE ?", "%pixiv%"]) do |post|
  post.file_ext = ""
  fix = PixivFix.new(post)
  begin
    fix.fix!
  rescue => x
    puts "- Skipping: #{x}"
  end
  puts "-" * 40
end
