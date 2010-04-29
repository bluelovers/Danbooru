require File.dirname(__FILE__) + '/../test_helper'

class PostControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup
    @test_number = 1
  end
  
  def create_default_posts
    p1 = create_post("tag1")
    p2 = create_post("tag2")
    p3 = create_post("tag3")
    p4 = create_post("tag4")
    [p1, p2, p3, p4]
  end
  
  def test_create
    get :upload, {}, {:user_id => 3}
    assert_response :success
    
    post :create, {:post => {:source => "", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test1.jpg"), :tags => "hoge", :rating => "Safe"}}
    p = Post.find(:first, :order => "id DESC")
    assert_equal("hoge", p.cached_tags)
    assert_equal("jpg", p.file_ext)
    assert_equal("s", p.rating)
    assert_equal(3, p.user_id)
    assert_equal(true, File.exists?(p.file_path))
    assert_equal(true, File.exists?(p.preview_path))
    
    # TODO: test duplicates
    # TODO: test privileges
    # TODO: test daily limits
  end
  
  def test_moderate
    ModQueuePost.destroy_all
    
    p1 = create_post("hoge", :status => "pending")
    p2 = create_post("hoge", :status => "active")
    p3 = create_post("moge", :status => "active")
    
    p2.flag!("sage", User.find(1))
    p2.reload
    assert_not_nil(p2.flag_detail)

    get :moderate, {}, {:user_id => 1}
    assert_response :success

    get :moderate, {:query => "moge"}, {:user_id => 1}
    assert_response :success
    
    post :moderate, {:id => p1.id, :commit => "Approve"}, {:user_id => 1}
    p1.reload
    assert_equal("active", p1.status)

    post :moderate, {:id => p3.id, :reason => "sage", :commit => "Delete"}, {:user_id => 1}
    p3.reload
    assert_equal("deleted", p3.status)
    assert_not_nil(p3.flag_detail)
    assert_equal("sage", p3.flag_detail.reason)

    assert_equal(0, ModQueuePost.count)
    post :moderate, {:id => "3", :commit => "Hide"}, {:user_id => 1}
    assert_equal(1, ModQueuePost.count)
  end
  
  def test_update
    p1 = create_post("hoge")
    
    post :update, {:post => {:tags => "moge", :rating => "Explicit"}, :id => p1.id}, {:user_id => 3}
    p1.reload
    assert_equal("moge", p1.cached_tags)
    assert_equal("e", p1.rating)
    
    assert_equal(2, p1.tag_history.size)
    post :update, {:post => {:rating => "Safe"}, :id => p1.id}, {:user_id => 3}
    assert_equal(3, p1.tag_history.size)
    
    p1.update_attribute(:is_rating_locked, true)
    post :update, {:post => {:rating => "Questionable"}, :id => p1.id}, {:user_id => 3}
    p1.reload
    assert_equal("s", p1.rating)
  end
  
  def test_destroy
    p1 = create_post("hoge", :user_id => 3)
    
    get :delete, {:id => p1.id}, {:user_id => 3}
    assert_response :success
    
    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 4}
    assert_redirected_to :controller => "user", :action => "login"
    p1.reload
    assert_equal("active", p1.status)
    
    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 3}
    assert_redirected_to :controller => "user", :action => "login"
    p1.reload
    assert_equal("active", p1.status)
    
    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 1}
    p1.reload
    assert_equal("deleted", p1.status)
    assert_not_nil(p1.flag_detail)
    assert_equal("sage", p1.flag_detail.reason)

    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 1}
    assert_nil(Post.find_by_id(p1.id))
  end
  
  def test_deleted_index
    get :deleted_index, {}, {:user_id => 3}
    assert_response :success
    
    get :deleted_index, {:user_id => 1}, {:user_id => 3}
    assert_response :success
  end
  
  def test_index
    create_default_posts
    
    get :index, {}, {:user_id => 3}
    assert_response :success
    
    get :index, {:tags => "tag1"}, {:user_id => 3}
    assert_response :success
    
    get :index, {:format => "json"}, {:user_id => 3}
    assert_response :success
    
    get :index, {:format => "xml"}, {:user_id => 3}
    assert_response :success
    
    get :index, {:tags => "-tag1"}, {:user_id => 3}
    assert_response :success
  end
  
  def test_atom
    create_default_posts
    
    get :atom, {}, {:user_id => 3}
    assert_response :success
    
    get :atom, {:tags => "tag1"}, {:user_id => 3}
    assert_response :success
  end
  
  def test_piclens
    create_default_posts
    
    get :piclens, {}, {:user_id => 3}
    assert_response :success
    
    get :piclens, {:tags => "tag1"}, {:user_id => 3}
    assert_response :success
  end
  
  def test_show
    get :show, {:id => 1}, {:user_id => 3}
    assert_response :success
  end
  
  def test_popular
    get :popular_by_day, {}, {:user_id => 3}
    assert_response :success
  end
  
  def test_revert_tags
    p1 = create_post("tag1")
    update_post(p1, :tags => "hoge")
    update_post(p1, :tags => "moge")
    
    history_id = p1.tag_history[-1].id
    
    post :revert_tags, {:id => p1.id, :history_id => history_id}, {:user_id => 3}
    p1.reload
    assert_equal("tag1", p1.cached_tags)
  end
  
  def test_vote
    p1 = create_post("tag1")
    
    post :vote, {:id => p1.id, :score => 1}, {:user_id => 3}
    p1.reload
    assert_equal(1, p1.score)

    post :vote, {:id => p1.id, :score => 1}, {:user_id => 3}
    p1.reload
    assert_equal(1, p1.score)
    
    p2 = create_post("tag2")

    post :vote, {:id => p2.id, :score => 5}, {:user_id => 3}
    p2.reload
    assert_equal(0, p2.score)
    
    post :vote, {:id => p2.id, :score => 1}, {:user_id => 4}
    p2.reload
    assert_equal(0, p2.score)
  end
  
  def test_flag
    p1 = create_post("tag1")
    
    post :flag, {:id => p1.id, :reason => "sage"}, {:user_id => 3}
    
    p1.reload
    assert_equal("flagged", p1.status)
    assert_not_nil(p1.flag_detail)
    assert_equal("sage", p1.flag_detail.reason)
  end
  
  def test_random
    get :random, {}, {:user_id => 3}
    assert_response :redirect
  end
  
  def test_undelete
    p1 = create_post("tag1", :status => "deleted")
    
    get :undelete, {:id => p1.id}, {:user_id => 2}
    p1.reload
    assert_equal("deleted", p1.status)
    
    post :undelete, {:id => p1.id, :commit => "Undelete"}, {:user_id => 2}
    
    p1.reload
    assert_equal("active", p1.status)
  end
end
