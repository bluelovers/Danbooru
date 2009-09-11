class Advertisement < ActiveRecord::Base
  validates_inclusion_of :ad_type, :in => %w(horizontal vertical)
  has_many :hits, :class_name => "AdvertisementHit"

  def hit!(ip_addr)
    AdvertisementHit.create(:ip_addr => ip_addr, :advertisement_id => id)
  end

  def hit_sum(start_date, end_date)
    AdvertisementHit.count(:conditions => ["advertisement_id = ? AND created_at BETWEEN ? AND ?", id, start_date, end_date])
  end
  
  def date_path
    created_at.strftime("%Y%m%d")
  end
  
  def image_url
    "/images/ads-#{date_path}/#{file_name}"
  end

  def image_path
    "#{RAILS_ROOT}/public/#{image_url}"
  end
  
  def file=(f)
    if f.size > 0
      self.created_at ||= Time.now
      self.file_name = f.original_filename
      FileUtils.mkdir_p(File.dirname(image_path))

      if f.local_path
        FileUtils.cp(f.local_path, image_path)
      else
        File.open(image_path, 'wb') {|nf| nf.write(f.read)}
      end
    
      imgsize = ImageSize.new(File.open(image_path, "rb"))
      self.width = imgsize.get_width
      self.height = imgsize.get_height
    end
  end
  
  def preview_width
    if width > 200 || height > 200
      if width < height
        ratio = 200.0 / height
        return (width * ratio).to_i
      else
        return 200
      end
    end      
  end
  
  def preview_height
    if width > 200 || height > 200
      if height < width
        ratio = 200.0 / width
        return (height * ratio)
      else
        return 200
      end
    end      
  end
end
