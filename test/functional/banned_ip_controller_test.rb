require File.dirname(__FILE__) + '/../test_helper'

class BannedIpControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup
    @banned_ip = create_banned_ip("1.2.3.4")
  end
  
  def test_new
    get :new, {}, {:user_id => 1}
    assert_response :success
  end
  
  def test_create
    post :create, {:banned_ip => {:ip_addr => "5.6.7.8", :reason => "test"}}, {:user_id => 1}
    assert(BannedIp.is_banned?("5.6.7.8"))
  end
  
  def test_index
    get :index, {}, {:user_id => 1}
    assert_response :success
  end
  
  def test_search_users
    get :search_users, {}, {:user_id => 1}
    assert_response :success
    
    wiki_page = create_wiki()
    get :search_users, {:user_ids => "1"}, {:user_id => 1}
    assert_response :success
  end

  def test_search_ip_addrs
    get :search_ip_addrs, {}, {:user_id => 1}
    assert_response :success
    
    wiki_page = create_wiki()
    get :search_ip_addrs, {:ip_addrs => "127.0.0.1"}, {:user_id => 1}
    assert_response :success
  end
  
  def test_destroy
    post :destroy, {:id => @banned_ip.id}, {:user_id => 1}
    assert(!BannedIp.is_banned?("1.2.3.4"))
  end
end
