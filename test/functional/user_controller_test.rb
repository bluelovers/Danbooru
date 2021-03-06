require File.dirname(__FILE__) + '/../test_helper'

class UserControllerTest < ActionController::TestCase
  fixtures :users, :table_data
  
  def setup_action_mailer
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def test_show
    get :show, {:id => 1}, {:user_id => 2}
    assert_response :success
  end
  
  def test_invites
    setup_action_mailer
    
    member = User.find(4)
    janitor = User.find(7)
    
    post :invites, {:member => {:name => "member", :level => 33}}, {:user_id => janitor.id}
    member.reload
    assert_equal(33, member.level)
  end
  
  def test_invite_for_user_with_negative_user_record_by_janitor
    member = User.find(4)
    mod = User.find(2)
    janitor = User.find(7)
    
    UserRecord.create(:score => -1, :user_id => member.id, :reported_by => mod.id, :body => "xxx")
    post :invites, {:member => {:name => "member", :level => 33}}, {:user_id => janitor.id}
    member.reload
    assert_equal(20, member.level)
  end
  
  def test_invite_for_user_with_negative_user_record_by_mod
    member = User.find(4)
    mod = User.find(2)
    janitor = User.find(7)
    
    UserRecord.create(:score => -1, :user_id => member.id, :reported_by => mod.id, :body => "xxx")
    post :invites, {:member => {:name => "member", :level => 33}}, {:user_id => mod.id}
    member.reload
    assert_equal(20, member.level)
  end
  
  def test_home
    get :home, {}, {}
    assert_response :success
    
    get :home, {}, {:user_id => 1}
    assert_response :success
  end
  
  def test_index
    get :index, {}, {}
    assert_response :success

    # TODO: more parameters
  end
  
  def test_authentication_failure
    user = create_user("bob")
    
    get :login, {}, {}
    assert_response :success
    
    post :authenticate, {:user => {:name => "bob", :password => "zugzug2"}, :url => "http://google.com"}, {}
    assert_not_nil(assigns(:current_user))
    assert_equal(true, assigns(:current_user).is_anonymous?)
  end
  
  def test_authentication_success
    user = create_user("bob")

    post :authenticate, {:user => {:name => "bob", :password => "zugzug1"}, :url => "http://google.com"}, {}
    assert_not_nil(assigns(:current_user))
    assert_equal(false, assigns(:current_user).is_anonymous?)
    assert_equal("bob", assigns(:current_user).name)
  end
  
  def test_create
    setup_action_mailer
    
    get :signup, {}, {}
    assert_response :success
    
    post :create, {:user => {:name => "mog", :email => "mog@danbooru.com", :password => "zugzug1", :password_confirmation => "zugzug1"}}
    mog = User.find_by_name("mog")
    assert_not_nil(mog)
  end
  
  def test_update
    get :edit, {}, {:user_id => 4}
    assert_response :success

    post :update, {:user => {:invite_count => 10, :receive_dmails => true}}, {:user_id => 4}
    user = User.find(4)
    assert_equal(0, user.invite_count)
    assert_equal(true, user.receive_dmails?)
  end
  
  def test_reset_password
    setup_action_mailer
    
    old_password_hash = User.find(1).password_hash
    
    get :reset_password
    assert_response :success
    
    post :reset_password, {:user => {:name => "admin", :email => "wrong@danbooru.com"}}
    assert_equal(old_password_hash, User.find(1).password_hash)

    post :reset_password, {:user => {:name => "admin", :email => "admin@danbooru.com"}}
    assert_not_equal(old_password_hash, User.find(1).password_hash)
  end
  
  def test_block
    setup_action_mailer
    
    get :block, {:id => 4}, {:user_id => 1}
    assert_response :success
    
    post :block, {:id => 4, :ban => {:reason => "bad", :duration => 5}}, {:user_id => 1}
    banned = User.find(4)
    assert_equal(CONFIG["user_levels"]["Blocked"], banned.level)
    
    get :show_blocked_users, {}, {:user_id => 1}
    assert_response :success
    
    post :unblock, {:user => {"4" => "1"}}, {:user_id => 1}
    banned.reload
    assert_equal(CONFIG["user_levels"]["Member"], banned.level)
  end
  
  def test_upload_limit
    get :upload_limit, {:id => 4}
    assert_response :success
  end
  
  def test_update_upload_limit
    get :edit_upload_limit, {:id => 4}, {:user_id => 1}
    assert_response :success
    
    post :update_upload_limit, {:id => 4, :user => {:upload_limit => 6}}, {:user_id => 1}
    assert_redirected_to :action => "show", :id => 4
    assert_equal(6, User.find(4).upload_limit)
  end
  
  def test_random
    get :random, {:id => 1}
    assert_response :success
  end
end
