require File.dirname(__FILE__) + '/../test_helper'

class AdvertisementTest < ActiveSupport::TestCase
  fixtures :users, :advertisements
  
  def test_hit
    assert_equal(0, AdvertisementHit.count)
    ad = Advertisement.find(1)
    ad.hit!("0.0.0.0")
    assert_equal(1, AdvertisementHit.count)
    assert_equal("0.0.0.0", AdvertisementHit.first.ip_addr)
    assert_equal(1, AdvertisementHit.first.advertisement_id)
    assert_equal(1, ad.hit_sum(1.day.ago, 1.day.from_now))
    assert_equal(0, ad.hit_sum(2.days.ago, 1.day.ago))
  end
end
