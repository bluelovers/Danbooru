module ArtistMethods
  module VersionMethods
    def self.included(m)
      m.before_save :initialize_version
      m.after_save :create_version
      m.has_many :versions, :class_name => "ArtistVersion", :order => "version desc", :dependent => :delete_all
    end
    
    def initialize_version
      if version.nil?
        self.version = 1
      end
    end

    def create_version
      cached_urls = artist_urls.map {|x| x.normalized_url}.join(" ")
      
      ArtistVersion.create(
        :artist_id => id,
        :version => version,
        :name => name,
        :updater_id => updater_id,
        :cached_urls => cached_urls,
        :is_active => is_active,
        :other_names_array => other_names_array,
        :group_name => group_name
      )
      
      Artist.execute_sql "UPDATE artists SET version = version + 1 WHERE id = #{id}"
    end
  end
end
