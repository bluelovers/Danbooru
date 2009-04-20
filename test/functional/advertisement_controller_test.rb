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
    
    post :create, {:ad => {:image_url => "test", :referral_url => "test", :ad_type => "vertical", :status => "active", :width => "500", :height => "500", :is_work_safe => "1"}}, {:user_id => 1}
    assert_equal(3, Advertisement.count)
    ad = Advertisement.find(:last)
    assert_equal("test", ad.image_url)
  end
  
  def test_update
    get :edit, {:id => 1}
    assert_response 302
    
    get :edit, {:id => 1}, {:user_id => 1}
    assert_response :success
    
    post :update, {:id => 1, :ad => {:image_url => "test", :referral_url => "test", :ad_type => "vertical", :status => "active", :width => "500", :height => "500", :is_work_safe => "1"}}, {:user_id => 1}
    ad = Advertisement.find(1)
    assert_equal("test", ad.image_url)
  end
  
  def test_redirect
    get :redirect_ad, {:id => 1}
    assert_redirected_to "referral url"
  end
end
