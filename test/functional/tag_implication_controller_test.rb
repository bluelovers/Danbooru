require File.dirname(__FILE__) + '/../test_helper'

class TagImplicationControllerTest < ActionController::TestCase
  fixtures :users
  
  def test_all
    post :create, {:tag_implication => {:predicate => "a", :consequent => "b"}}, {:user_id => 3}
    t = TagImplication.find_by_predicate_id(Tag.find_by_name("a").id)
    assert_not_nil(t)
    
    post :update, {:implications => {t.id => "1"}, :commit => "Approve"}, {:user_id => 1}
    t.reload
    assert_equal(false, t.is_pending?)
    
    get :index
    assert_response :success
    
    post :update, {:implications => {t.id => "1"}, :commit => "Delete"}, {:user_id => 1}
    assert_nil(TagImplication.find_by_id(t.id))
  end
end
