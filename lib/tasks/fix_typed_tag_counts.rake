namespace :fix do
  desc 'Update posts with typed tag counts'
  task :typed_tag_counts => :environment do
    Post.find_in_batches(:conditions => "general_tag_count = 0 AND artist_tag_count = 0 AND character_tag_count = 0 AND copyright_tag_count = 0") do |group|
      group.each do |post|
        g, a, ch, co = 0, 0, 0, 0
        
        post.cached_tags.scan(/\S+/).each do |tag|
          tag_type, count = Tag.type_and_count(tag)
          
          if tag_type == "General"
            g += 1

          elsif tag_type == "Artist"
            a += 1

          elsif tag_type == "Character"
            ch += 1

          elsif tag_type == "Copyright"
            co += 1
          end        
        end
        
        ActiveRecord::Base.connection.execute("UPDATE posts SET general_tag_count = #{g}, artist_tag_count = #{a}, character_tag_count = #{ch}, copyright_tag_count = #{co} WHERE id = #{post.id}")
      end
    end
  end
end
