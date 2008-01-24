class ReportController < ApplicationController
  layout 'default'
  
  def tags
    stats = Tag.usage_stats(3.months.ago, Time.now)
    GoogleChart::PieChart.new("600x300", "All Tags", false) do |pc|
      stats.each do |stat|
        pc.data stat["name"], stat["post_count"].to_i
      end
      
      @all_tags_url = pc.to_url
    end
    
    stats = Tag.usage_stats(3.months.ago, 2.months.ago, :type => :artist)
    GoogleChart::PieChart.new("600x300", "Artist Tags", false) do |pc|
      stats.each do |stat|
        pc.data stat["name"], stat["post_count"].to_i
      end
      
      @artist_tags_url = pc.to_url
    end
  end
end
