require File.dirname(__FILE__) + '/../test_helper'

# There's a bug where setup isn't called in functional tests
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.deliveries = []

class AdminControllerTest < ActionController::TestCase
  fixtures :users
  
  def test_index
    get :index, {}, {:user_id => 1}
    assert_response :success
  end
  
  def test_edit_user
    get :edit_user, {}, {:user_id => 1}
    assert_response :success
    
    post :edit_user, {:user => {:name => "admin", :level => 10}}, {:user_id => 1}
    assert_equal(10, User.find(1).level)
  end
  
  def test_reset_password
    get :reset_password, {:user => {:name => "admin"}}, {:user_id => 1}
    assert_response :success
    
    admin = User.find(1)
    old_password_hash = admin.password_hash
    
    post :reset_password, {:user => {:name => "admin"}}, {:user_id => 1}
    admin.reload
    assert_not_equal(old_password_hash, admin.password_hash)
  end
  
  if CONFIG["enable_caching"]
    def test_cache_stats
      get :cache_stats, {}, {:user_id => 1}
      assert_response :success
      
      # TODO: test different parameters
    end
  end
end
