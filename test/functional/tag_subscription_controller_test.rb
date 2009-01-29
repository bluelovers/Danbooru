require File.dirname(__FILE__) + '/../test_helper'

class TagSubscriptionControllerTest < ActionController::TestCase
  fixtures :users
  
  def test_all
    assert_equal(0, TagSubscription.count)
    
    get :index, {}, {:user_id => 1}
    assert_response :success
    
    post :create, {:format => "js"}, {:user_id => 1}
    assert_response :success
    assert_equal(1, TagSubscription.count)
    
    ts = TagSubscription.find(:first)  
    post :update, {:tag_subscription => {ts.id => {"tag_query" => "bob"}}}, {:user_id => 1}
    assert_redirected_to :controller => "user", :action => "edit"
    ts.reload
    assert_equal("bob", ts.tag_query)
    
    get :index, {}, {:user_id => 1}
    assert_response :success
    
    post :destroy, {:format => "js", :id => ts.id}, {:user_id => 1}
    assert_response :success
    assert_equal(0, TagSubscription.count)
  end
end
