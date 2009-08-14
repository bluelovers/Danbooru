class ArtistVersion < ActiveRecord::Base
  belongs_to :artist
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  
  def urls
    cached_urls.split(" ")
  end
end
