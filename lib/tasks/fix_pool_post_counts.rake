namespace :fix do
  desc 'Fix post counts for pools'
  task :pool_post_counts => :environment do
    Pool.find(:all).each do |pool|
      pool.update_attribute(:post_count, PoolPost.count(:conditions => "pool_id = #{pool.id}"))
    end
  end
end
