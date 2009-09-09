#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../config/environment'

Post.find_each(:select => "id, general_tag_count, artist_tag_count, character_tag_count, copyright_tag_count") do |post|
  puts post.id
  general, artist, character, copyright = 0, 0, 0, 0
  post.cached_tags.split(/ /).each do |tag|
    x, _ = Tag.type_and_count(tag)
    
    case x
    when 0
      general += 1
      
    when 1
      artist += 1
      
    when 3
      copyright += 1
      
    when 4
      character += 1
    end
  end
  
  ActiveRecord::Base.connection.execute_sql("UPDATE posts SET general_tag_count = #{general}, artist_tag_count = #{artist}, copyright_tag_count = #{copyright}, character_tag_count = #{character} WHERE id = #{post.id}")
end
