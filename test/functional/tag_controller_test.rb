require File.dirname(__FILE__) + '/../test_helper'

class TagControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup
    @test_number = 1
  end
  
  def test_cloud
    default_create_post("hoge")
    default_create_post("hoge moge")
    default_create_post("lodge")
    
    get :cloud, {}, {}
    assert_response :success
  end
  
  def test_index
    default_create_post("hoge")
    default_create_post("hoge moge")
    default_create_post("lodge")

    get :index, {}, {}
    assert_response :success
    
    # TODO: test other params
  end

  def test_mass_edit
    get :mass_edit, {}, {:user_id => 2}
    assert_response :success

    # Can't easily test the mass_edit action. The daemon process does the actual work.
    # Anything we create inside this test is created within a transaction, so any database
    # connection outside of this one won't see any changes. We can disable transactional
    # fixtures but this interferes with other tests. Just assume the action works correctly
    # and test the logic of mass_edit in the unit tests.
  end
  
  def test_edit_preview
    p1 = default_create_post("hoge")
    p2 = default_create_post("hoge moge")
    p3 = default_create_post("lodge")

    get :edit_preview, {:tags => "hoge"}, {:user_id => 2}
    assert_response :success
  end
  
  def test_update
    p1 = default_create_post("hoge")

    get :edit, {:name => "hoge"}, {:user_id => 3}
    assert_response :success
    
    post :update, {:tag => {:name => "hoge", :tag_type => CONFIG["tag_types"]["Artist"]}}, {:user_id => 3}
    assert_equal(CONFIG["tag_types"]["Artist"], Tag.find_by_name("hoge").tag_type)
  end
  
  def test_related
    p1 = default_create_post("hoge")
    p2 = default_create_post("hoge moge")
    p3 = default_create_post("lodge")
    
    get :related, {:tags => "hoge", :format => "json"}, {}
    assert_response :success
  end
  
  def test_popular
    p1 = default_create_post("hoge")
    p2 = default_create_post("hoge moge")
    p3 = default_create_post("lodge")

    get :popular_by_day, {}, {}
    assert_response :success
    
    get :popular_by_week, {}, {}
    assert_response :success
    
    get :popular_by_month, {}, {}
    assert_response :success
  end
end
