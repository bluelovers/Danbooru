class ReportController < ApplicationController
  layout 'default'
  
  def tag_changes
    @users = Report.usage_by_user("post_tag_histories", 3.days.ago, Time.now)
    GoogleChart::PieChart.new("600x300", "Tag Changes", false) do |pc|
      @users.each do |user|
        pc.data user["name"], user["change_count"].to_i
      end
      
      @tag_changes_url = pc.to_url
    end
  end
  
  def note_changes
    @users = Report.usage_by_user("note_versions", 3.days.ago, Time.now)
    GoogleChart::PieChart.new("600x300", "Note Changes", false) do |pc|
      @users.each do |user|
        pc.data user["name"], user["change_count"].to_i
      end
      
      @note_changes_url = pc.to_url
    end
  end
  
  def wiki_changes
    @users = Report.usage_by_user("wiki_page_versions", 3.days.ago, Time.now)
    GoogleChart::PieChart.new("600x300", "Wiki Changes", false) do |pc|
      @users.each do |user|
        pc.data user["name"], user["change_count"].to_i
      end
      
      @wiki_changes_url = pc.to_url
    end
  end
end
