require File.dirname(__FILE__) + '/../test_helper'

class PostTagHistoryControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup
    @test_number = 1
  end
  
  def test_index
    p1 = create_post("tag1")
    update_post(p1, :tags => "moge")
    update_post(p1, :tags => "hoge")
    
    get :index, {}, {:user_id => 3}
    assert_response :success
  end
  
  def test_revert
    p1 = create_post("tag1")
    update_post(p1, :tags => "moge")
    update_post(p1, :tags => "hoge")
    
    post :revert, {:id => p1.tag_history[-1].id, :commit => "Yes"}, {:user_id => 3}
    p1.reload
    assert_equal("tag1", p1.cached_tags)
  end
  
  def test_undo
    p1 = create_post("a")
    update_post(p1, :tags => "a b")

    post :undo, {:id => p1.tag_history[0].id}, {:user_id => 3}
    p1.reload
    assert_equal("a", p1.cached_tags)
  end
end
