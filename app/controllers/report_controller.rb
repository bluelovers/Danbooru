class ReportController < ApplicationController
  layout "default"

  def tags
    @tags_1 = Tag.count_by_period(1.day.ago, Time.now)
    @tags_10 = Tag.count_by_period(10.days.ago, Time.now)
    @tags_100 = Tag.count_by_period(100.days.ago, Time.now)
  end

  def users
    @users_1 = User.find(:all, :order => "id desc", :conditions => ["created_at > ?", 1.day.ago])
    @users_10 = User.find(:all, :order => "id desc", :conditions => ["created_at > ?", 10.days.ago])
    @users_100 = User.find(:all, :order => "id desc", :conditions => ["created_at > ?", 100.days.ago])
  end
end
