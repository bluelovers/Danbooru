namespace :pools do
  desc 'Fix ordering of posts in pools (needed after r1454)'
  task :fix_ordering => :environment do
    Pool.find(:all).each do |pool|
      pp = pool.pool_posts

      pp.each_index do |i|
        pp[i].next_post_id = pp[i + 1].post_id unless i == pp.size - 1
        pp[i].prev_post_id = pp[i - 1].post_id unless i == 0
        pp[i].save
      end
    end
  end
end

