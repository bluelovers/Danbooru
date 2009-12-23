class ArtistVersion < ActiveRecord::Base
  default_scope :select => "artist_versions.*, coalesce(array_to_string(other_names_array, ', '), '') AS other_names_string"

  belongs_to :artist
  belongs_to :updater, :class_name => "User", :foreign_key => "updater_id"
  
  def urls
    cached_urls.split(" ")
  end
  
  def updater_name
    User.find_name(updater_id).tr("_", " ")
  end
  
  def other_names
    if self["other_names_string"]
      self.other_names_string
    else
      
    end
  end
end
