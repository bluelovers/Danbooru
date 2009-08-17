class ArtistVersion < ActiveRecord::Base
  belongs_to :artist
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  
  def urls
    cached_urls.split(" ")
  end
  
  def updater_name
    User.find_name(updater_id).tr("_", " ")
  end
end
