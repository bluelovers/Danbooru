require File.dirname(__FILE__) + '/../test_helper'

class TagImplicationControllerTest < ActionController::TestCase
  fixtures :users
  
  def test_all
    a = Tag.find_or_create_by_name('a')

    post :create, {:tag_implication => {:predicate => "a", :consequent => "b"}}, {:user_id => 3}
    assert_redirected_to :controller => 'user', :action => 'login'
    assert_nil(TagImplication.find_by_predicate_id(a.id))

    post :create, {:tag_implication => {:predicate => "a", :consequent => "b"}}, {:user_id => 1}
    t = TagImplication.find_by_predicate_id(a.id)
    assert_not_nil(t)
    
    get :index
    assert_response :success

    post :update, { :commit => 'Delete', :implications => { t.id => 0 }, :reason => 'foo' }, { :user_id => 3 }
    assert_redirected_to :controller => 'user', :action => 'login'
    assert_not_nil(TagImplication.find_by_predicate_id(a.id))

    post :update, { :commit => 'Delete', :implications => { t.id => 0 }, :reason => 'foo' }, { :user_id => 1 }
    assert_redirected_to :action => 'index'
    assert_nil(TagImplication.find_by_predicate_id(a.id))
    
    # Can't easily test the update action. The daemon process does the actual work.
    # Anything we create inside this test is created within a transaction, so any database
    # connection outside of this one won't see any changes. We can disable transactional
    # fixtures but this interferes with other tests. Just assume the action works correctly
    # and test the logic of update in the unit tests.
  end
end
