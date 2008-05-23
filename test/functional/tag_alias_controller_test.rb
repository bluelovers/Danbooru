require File.dirname(__FILE__) + '/../test_helper'

class TagAliasControllerTest < ActionController::TestCase
  fixtures :users
  
  def test_all
    post :create, {:tag_alias => {:name => "a", :alias => "b"}}, {:user_id => 3}
    t = TagAlias.find_by_name("a")
    assert_not_nil(t)
    
    post :update, {:aliases => {t.id => "1"}, :commit => "Approve"}, {:user_id => 1}
    t.reload
    assert_equal(false, t.is_pending?)
    
    get :index
    assert_response :success
    
    post :update, {:aliases => {t.id => "1"}, :commit => "Delete"}, {:user_id => 1}
    assert_nil(TagAlias.find_by_id(t.id))
  end
end
