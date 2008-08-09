namespace :sample_images do
  def regen(post)
    unless post.regenerate_sample
      unless post.errors.empty?
    	error = post.errors.full_messages.join(", ")
    	puts "Error: post ##{post_.id}: #{error}"
      end
    
      return false
    end

    puts "post ##{post.id}"
    post.save!
    return true
  end

  desc 'Create missing sample images'
  task :create_missing => :environment do
    Post.find_by_sql("SELECT p.* FROM posts p ORDER BY p.id DESC").each do |post|
      regen(post)
    end
  end
end

