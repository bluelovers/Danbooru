require 'activerecord.rb'

class User < ActiveRecord::Base
end

class UserBlacklistedTags < ActiveRecord::Base
end

namespace :blacklisted_tags do
  def SetDefaultBlacklistedTags
    User.transaction do
      User.find(:all, :order => "id").each do |user|
        CONFIG["default_blacklists"].each do |b|
          UserBlacklistedTags.create(:user_id => user.id, :tags => b)
        end
      end
    end
  end

  desc 'Add default_blacklists to all users'
  task :add_defaults => :environment do
    SetDefaultBlacklistedTags()
  end
end
