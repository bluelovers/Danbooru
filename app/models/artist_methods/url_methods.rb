module ArtistMethods
  module UrlMethods
    module ClassMethods
      def find_all_by_url(url)
        url = ArtistUrl.normalize(url)
        artists = []

        while artists.empty? && url.size > 10
          u = url.gsub(/\/+$/, "") + "/"
          u = u.to_escaped_for_sql_like.gsub(/\*/, '%') + '%'
          artists += Artist.find(:all, :joins => "JOIN artist_urls ON artist_urls.artist_id = artists.id", :conditions => ["artists.is_active = TRUE AND artist_urls.normalized_url LIKE ? ESCAPE E'\\\\'", u], :order => "artists.name")

          # Remove duplicates based on name
          artists = artists.inject({}) {|all, artist| all[artist.name] = artist ; all}.values
          url = File.dirname(url)
        end

        return artists[0, 20]
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
      m.after_save :commit_urls
      m.has_many :artist_urls, :dependent => :delete_all
    end
    
    def commit_urls
      if @urls
        artist_urls.clear

        @urls.scan(/\S+/).each do |url|
          artist_urls.create(:url => url)
        end
      end
    end
    
    def urls=(urls)
      @urls = urls
    end
    
    def urls
      @urls || artist_urls.map {|x| x.url}.join("\n")
    end
  end
end
