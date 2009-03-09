class Advertisement < ActiveRecord::Base
  validates_inclusion_of :ad_type, :in => %w(horizontal vertical)
  has_many :hits, :class_name => "AdvertisementHit"

  def hit!(ip_addr)
    AdvertisementHit.create(:ip_addr => ip_addr, :advertisement_id => id)
  end

  def hit_sum(start_date, end_date)
    AdvertisementHit.count(:conditions => ["created_at BETWEEN ? AND ?", start_date, end_date])
  end
end
