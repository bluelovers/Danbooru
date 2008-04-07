namespace :users do
  desc 'Reset levels for blocked users who don\'t have active bans'
  task :fix_blocked_users => :environment do
    User.find(:all, :conditions => "level = 10 AND id NOT IN (SELECT user_id FROM bans)").each do |user|
      user.update_attribute(:level, 20)
    end
  end
end

