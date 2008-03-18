namespace :sample_images do
  def regen(post)
    unless post.regenerate_sample
    	unless post.errors.empty?
    	  error = post.errors.full_messages.join(", ")
    	  print "Error: post #" + post.id.to_s + ": " + error + "\n"
    	end
	    
	    return false
    end

    post.save!
    return true;
  end

  desc 'Create missing sample images'
  task :create_missing => :environment do
    Post.find_by_sql("SELECT p.* FROM posts p WHERE p.status != 'deleted' and width >= 1275 ORDER BY p.id DESC").each do |post|
      print "post #" + post.id.to_s + " ...\n";
      regen(post)
    end
  end
end

