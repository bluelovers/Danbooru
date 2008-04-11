class ArtistUrl < ActiveRecord::Base
  before_save :normalize
  
  def self.normalize(url)
    if url.nil?
      return nil
    else
      url = url.gsub(/\/$/, "")
      url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/img\d+\.pixiv\.net/, "http://img.pixiv.net")
      return url
    end
  end

  def normalize
    self.normalized_url = self.class.normalize(self.url)
  end
end
