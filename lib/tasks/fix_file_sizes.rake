namespace :fix do
  desc 'Update posts with actual file sizes'
  task :file_sizes => :environment do
    Post.find_in_batches(:conditions => "file_size = 0") do |group|
      group.each do |post|
        if File.exists?(post.file_path)
          size = File.size(post.file_path)
        else
          size = 0
        end
        
        ActiveRecord::Base.connection.execute("UPDATE posts SET file_size = #{size} WHERE id = #{post.id}")
      end
    end
  end
end
