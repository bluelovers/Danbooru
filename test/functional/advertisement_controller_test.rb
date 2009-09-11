require File.dirname(__FILE__) + '/../test_helper'

class AdvertisementControllerTest < ActionController::TestCase
  fixtures :users, :advertisements
  
  def test_index
    get :index
    assert_response :success
  end
  
  def test_create
    assert_equal(2, Advertisement.count)
    
    get :new
    assert_response 302
    
    get :new, {}, {:user_id => 1}
    assert_response :success
    
    post :create, {:ad => {:file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test1.jpg"), :referral_url => "test", :ad_type => "vertical", :status => "active", :width => "500", :height => "500", :is_work_safe => "1"}}, {:user_id => 1}
    assert_equal(3, Advertisement.count)
    ad = Advertisement.find(:last)
    assert_equal("/images/ads-#{Time.now.strftime('%Y%m%d')}/test1.jpg", ad.image_url)
  end
  
  def test_update
    get :edit, {:id => 1}
    assert_response 302
    
    get :edit, {:id => 1}, {:user_id => 1}
    assert_response :success
    
    post :update, {:id => 1, :ad => {:file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test1.jpg"), :referral_url => "test", :ad_type => "vertical", :status => "active", :width => "500", :height => "500", :is_work_safe => "1"}}, {:user_id => 1}
    ad = Advertisement.find(1)
    assert_equal("/images/ads-20010101/test1.jpg", ad.image_url)
  end
  
  def test_redirect
    assert_equal(0, AdvertisementHit.count)
    get :redirect_ad, {:id => 1}
    assert_redirected_to "referral url"
    assert_equal(1, AdvertisementHit.count)
    assert_equal(1, AdvertisementHit.first.advertisement_id)
    assert_equal("0.0.0.0", AdvertisementHit.first.ip_addr)
  end
end
