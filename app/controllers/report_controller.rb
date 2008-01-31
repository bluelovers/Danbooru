class ReportController < ApplicationController
  layout 'default'
  
  def tag_changes
    @users = PostTagHistory.report_usage(3.days.ago, Time.now)
    GoogleChart::PieChart.new("600x300", "Tag Changes", false) do |pc|
      @users.each do |user|
        pc.data user["name"], user["change_count"].to_i
      end
      
      @tag_changes_url = pc.to_url
    end
  end
end
