require 'test_helper'

class TestJanitorControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  test "index works" do
    create_test_janitor(4)
    get :index, {}, {:user_id => 1}
    assert_response :success
  end
  
  test "new works" do
    create_test_janitor(4)
    get :new, {}, {:user_id => 1}
    assert_response :success
  end
  
  test "create" do
    get :create, {:name => "member"}, {:user_id => 1}
    assert_redirected_to :action => "index"
    user = User.find(4)
    assert_equal(34, user.level)
    assert_not_nil(user.test_janitor)
    assert_equal(1, TestJanitor.count)
    assert_equal(20, user.test_janitor.original_level)
  end
  
  test "promote" do
    janitor = create_test_janitor(4)
    get :promote, {:id => janitor.id}, {:user_id => 1}
    assert_redirected_to :action => "index"
    user = User.find(4)
    assert_equal(35, user.level)
    assert_not_nil(user.test_janitor)
    assert_not_nil(user.test_janitor.promotion_date)
  end
  
  test "demote" do
    janitor = create_test_janitor(4)
    assert_equal(1, ActionMailer::Base.deliveries.size)
    get :demote, {:id => janitor.id}, {:user_id => 1}
    assert_redirected_to :action => "index"
    user = User.find(4)
    assert_equal(20, user.level)
    assert_nil(user.test_janitor)
    assert_equal(1, user.user_records.neutral.count)
    assert_equal(2, ActionMailer::Base.deliveries.size)
  end
end
